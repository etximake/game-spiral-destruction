## VideoRecorder.gd
## Quay màn hình game qua OBS WebSocket.
## Tự động bắt đầu/dừng recording theo lifecycle simulation.
## Cấu hình: đặt trong config.json → "recording" section.
##
## OBS WebSocket 5.x Protocol:
##   op 0: Hello (server → client)
##   op 1: Identify (client → server)
##   op 2: Identified (server → client)
##   op 6: Request (client → server)
##   op 7: RequestResponse (server → client)
##   op 9: IdentifyFailed (server → client)
extends Node

# ── Config (từ GameManager) ───────────────────────────────────────────────────
var _enabled: bool = false
var _host: String = "127.0.0.1"
var _port: int = 4455
var _password: String = "12345678"
var _connect_timeout: float = 4.0
var _request_timeout: float = 4.0
var _auto_start: bool = true
var _auto_stop: bool = true
var _verbose: bool = true

# ── OBS WebSocket State ───────────────────────────────────────────────────────
var _socket: WebSocketPeer = WebSocketPeer.new()
var _identified: bool = false
var _identify_sent: bool = false
var _pending_responses: Dictionary = {}
var _next_request_id: int = 1
var _last_error: String = ""
var _is_recording: bool = false

# ── Lifecycle ─────────────────────────────────────────────────────────────────
func _ready() -> void:
	# Config chưa sẵn sàng ở _ready() (GameScene chưa load mode).
	# Đợi simulation_ready để load config rồi mới kết nối OBS.
	var bus = get_node_or_null("/root/EventBus")
	if bus:
		bus.simulation_ready.connect(_on_simulation_ready)
		if _auto_stop:
			bus.simulation_completed.connect(_on_simulation_completed)
			bus.simulation_stuck.connect(_on_simulation_stuck)

func _on_simulation_ready(_mode_id: String) -> void:
	_load_config()
	if not _enabled:
		_log("VideoRecorder disabled in config")
		return

	# Kết nối tới OBS WebSocket
	_connect_obs()

	# Lắng nghe Space để bắt đầu recording (chỉ 1 lần)
	var bus = get_node_or_null("/root/EventBus")
	if bus and _auto_start and not bus.simulation_start_requested.is_connected(_on_simulation_start_requested):
		bus.simulation_start_requested.connect(_on_simulation_start_requested)

func _process(_delta: float) -> void:
	if not _enabled:
		return
	_poll_socket()

func _exit_tree() -> void:
	_close_socket()

# ── Public API ────────────────────────────────────────────────────────────────

## Bắt đầu ghi hình qua OBS
func start_recording(timeout: float = -1.0) -> bool:
	if not _enabled:
		_log("Recording skipped (disabled)")
		return true
	var t: float = _request_timeout if timeout <= 0.0 else timeout
	var ready: bool = await _ensure_ready(t)
	if not ready:
		_log("OBS start skipped: %s" % _last_error)
		return false
	var response: Dictionary = await _send_request("StartRecord", {}, t)
	var ok: bool = _is_request_success(response, true)
	if ok:
		_is_recording = true
		_log("OBS StartRecord OK")
	else:
		_log("OBS StartRecord failed: %s" % _request_status(response))
	return ok

## Dừng ghi hình qua OBS
func stop_recording(timeout: float = -1.0) -> bool:
	if not _enabled:
		return true
	var t: float = _request_timeout if timeout <= 0.0 else timeout
	var ready: bool = await _ensure_ready(t)
	if not ready:
		_log("OBS stop skipped: %s" % _last_error)
		return false
	var response: Dictionary = await _send_request("StopRecord", {}, t)
	var ok: bool = _is_request_success(response, true)
	if ok:
		_is_recording = false
		_log("OBS StopRecord OK")
	else:
		_log("OBS StopRecord failed: %s" % _request_status(response))
	return ok

## Kiểm tra OBS có sẵn sàng không
func is_available(timeout: float = -1.0) -> bool:
	if not _enabled:
		return false
	var t: float = _connect_timeout if timeout <= 0.0 else timeout
	var ready: bool = await _ensure_ready(t)
	if ready:
		_log("OBS available")
	else:
		_log("OBS unavailable: %s" % _last_error)
	return ready

## Trả về true nếu đang ghi hình
func is_recording() -> bool:
	return _is_recording

# ── Signal Handlers (EventBus) ────────────────────────────────────────────────

func _on_simulation_start_requested(_mode_id: String) -> void:
	_log("Space pressed -> start recording now")
	await start_recording()

func _on_simulation_completed(_mode_id: String, _duration: float) -> void:
	_log("Simulation completed -> auto stop recording")
	await stop_recording()

func _on_simulation_stuck(_mode_id: String, _radius: float) -> void:
	_log("Simulation stuck -> auto stop recording")
	await stop_recording()

# ── OBS WebSocket Connection ──────────────────────────────────────────────────

func _connect_obs() -> void:
	_reset_socket_state()
	var url: String = "ws://%s:%d" % [_host, _port]
	var err: int = _socket.connect_to_url(url)
	if err != OK:
		_last_error = "connect_to_url failed (%d)" % err
		_log("OBS connection error: %s" % _last_error)

func _ensure_ready(timeout: float) -> bool:
	if _is_socket_identified():
		return true

	_reset_socket_state()
	var url: String = "ws://%s:%d" % [_host, _port]
	var err: int = _socket.connect_to_url(url)
	if err != OK:
		_last_error = "connect_to_url failed (%d)" % err
		return false

	var deadline: int = Time.get_ticks_msec() + int(maxf(0.1, timeout) * 1000.0)
	while Time.get_ticks_msec() <= deadline:
		_poll_socket()
		if _is_socket_identified():
			return true
		var state: int = _socket.get_ready_state()
		if state == WebSocketPeer.STATE_CLOSED and _identify_sent:
			break
		await get_tree().process_frame

	if _last_error.is_empty():
		_last_error = "timeout waiting OBS identify"
	return false

# ── OBS WebSocket Protocol ────────────────────────────────────────────────────

func _poll_socket() -> void:
	if _socket == null:
		return
	var state: int = _socket.get_ready_state()
	if state in [WebSocketPeer.STATE_CONNECTING, WebSocketPeer.STATE_OPEN, WebSocketPeer.STATE_CLOSING]:
		_socket.poll()
	if _socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return

	while _socket.get_available_packet_count() > 0:
		var packet: PackedByteArray = _socket.get_packet()
		var text: String = packet.get_string_from_utf8()
		_handle_message(text)

func _handle_message(text: String) -> void:
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var msg: Dictionary = parsed as Dictionary
	var op: int = int(msg.get("op", -1))
	var d: Dictionary = msg.get("d", {}) as Dictionary if typeof(msg.get("d")) == TYPE_DICTIONARY else {}

	match op:
		0:  # Hello
			_handle_hello(d)
		2:  # Identified
			_identified = true
			_log("OBS identified successfully")
		7:  # RequestResponse
			var rid: String = str(d.get("requestId", "")).strip_edges()
			if not rid.is_empty():
				_pending_responses[rid] = d
		9:  # IdentifyFailed
			_last_error = "OBS identify failed (password?)"
			_log(_last_error)
			_close_socket()

func _handle_hello(data: Dictionary) -> void:
	var identify: Dictionary = {"rpcVersion": 1}
	var auth: Variant = data.get("authentication", null)
	if typeof(auth) == TYPE_DICTIONARY:
		var auth_data: Dictionary = auth as Dictionary
		if _password.strip_edges().is_empty():
			_last_error = "OBS requires password but none configured"
			_log(_last_error)
			_close_socket()
			return
		var challenge: String = str(auth_data.get("challenge", ""))
		var salt: String = str(auth_data.get("salt", ""))
		identify["authentication"] = _build_auth(_password, challenge, salt)

	_send_json({"op": 1, "d": identify})
	_identify_sent = true

func _send_request(request_type: String, request_data: Dictionary, timeout: float) -> Dictionary:
	if not _is_socket_identified():
		return {}

	var rid: String = str(_next_request_id)
	_next_request_id += 1
	var payload: Dictionary = {
		"requestType": request_type,
		"requestId": rid,
	}
	if not request_data.is_empty():
		payload["requestData"] = request_data
	_send_json({"op": 6, "d": payload})

	var deadline: int = Time.get_ticks_msec() + int(maxf(0.1, timeout) * 1000.0)
	while Time.get_ticks_msec() <= deadline:
		_poll_socket()
		if _pending_responses.has(rid):
			var resp: Variant = _pending_responses.get(rid, {})
			_pending_responses.erase(rid)
			return resp as Dictionary if typeof(resp) == TYPE_DICTIONARY else {}
		if _socket.get_ready_state() == WebSocketPeer.STATE_CLOSED:
			break
		await get_tree().process_frame

	_last_error = "timeout waiting OBS response for %s" % request_type
	return {}

func _send_json(payload: Dictionary) -> void:
	if _socket == null or _socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return
	_socket.send_text(JSON.stringify(payload))

# ── Auth ──────────────────────────────────────────────────────────────────────

func _build_auth(password: String, challenge: String, salt: String) -> String:
	var secret: PackedByteArray = (password + salt).to_utf8_buffer()
	var secret_hash: PackedByteArray = _sha256(secret)
	var secret_b64: String = Marshalls.raw_to_base64(secret_hash)
	var auth_src: PackedByteArray = (secret_b64 + challenge).to_utf8_buffer()
	var auth_hash: PackedByteArray = _sha256(auth_src)
	return Marshalls.raw_to_base64(auth_hash)

func _sha256(buffer: PackedByteArray) -> PackedByteArray:
	var hasher := HashingContext.new()
	hasher.start(HashingContext.HASH_SHA256)
	hasher.update(buffer)
	return hasher.finish()

# ── Helpers ───────────────────────────────────────────────────────────────────

func _is_socket_identified() -> bool:
	return _socket != null and _socket.get_ready_state() == WebSocketPeer.STATE_OPEN and _identified

func _close_socket() -> void:
	if _socket == null:
		return
	var state: int = _socket.get_ready_state()
	if state in [WebSocketPeer.STATE_CONNECTING, WebSocketPeer.STATE_OPEN]:
		_socket.close()

func _reset_socket_state() -> void:
	_close_socket()
	_socket = WebSocketPeer.new()
	_identified = false
	_identify_sent = false
	_pending_responses.clear()
	_last_error = ""

func _is_request_success(response: Dictionary, allow_already: bool) -> bool:
	if response.is_empty():
		return false
	var status: Variant = response.get("requestStatus", {})
	if typeof(status) != TYPE_DICTIONARY:
		return false
	var s: Dictionary = status as Dictionary
	if bool(s.get("result", false)):
		return true
	if not allow_already:
		return false
	var code: int = int(s.get("code", 0))
	var comment: String = str(s.get("comment", "")).to_lower()
	if comment.contains("already") or code in [504, 505]:
		return true
	return false

func _request_status(response: Dictionary) -> String:
	if response.is_empty():
		return _last_error if not _last_error.is_empty() else "empty_response"
	var status: Variant = response.get("requestStatus", {})
	if typeof(status) != TYPE_DICTIONARY:
		return "missing_request_status"
	var s: Dictionary = status as Dictionary
	return "code=%d comment=%s" % [int(s.get("code", 0)), str(s.get("comment", ""))]

func _load_config() -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.has_method("get_current_config"):
		var cfg: Dictionary = gm.get_current_config()
		var rec: Dictionary = cfg.get("recording", {})
		_enabled = rec.get("enabled", false)
		_host = rec.get("host", "127.0.0.1")
		_port = rec.get("port", 4455)
		_password = rec.get("password", "")
		_connect_timeout = rec.get("connect_timeout", 4.0)
		_request_timeout = rec.get("request_timeout", 4.0)
		_auto_start = rec.get("auto_start", true)
		_auto_stop = rec.get("auto_stop", true)
		_verbose = rec.get("verbose", true)

func _log(message: String) -> void:
	if not _verbose:
		return
	print("[VideoRecorder] %s" % message)
