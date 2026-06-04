## GameManager.gd
## Singleton — State machine trung tâm + Mode registry (config-driven).
## Quản lý vòng đời simulation: IDLE → RUNNING → COMPLETED → RESETTING → RUNNING
extends Node

# ── Enum trạng thái ───────────────────────────────────────────────────────────
enum State {
	IDLE,       # Chờ bắt đầu (scene vừa load)
	RUNNING,    # Simulation đang chạy
	COMPLETED,  # Win condition đạt được, đang hiện end screen
	RESETTING,  # Đang reset (tức thì, không reload scene)
}

# ── Mode Config Registry ──────────────────────────────────────────────────────
## Ánh xạ mode_id → đường dẫn file config JSON.
## Mỗi mode có 1 file config.json trong thư mục mode của nó.
const MODE_CONFIG_REGISTRY: Dictionary = {
	"spiral": "res://Modes/SpiralDestruction/config.json",
}

# ── State ─────────────────────────────────────────────────────────────────────
var current_state: State = State.IDLE
var current_mode_id: String = ""
var _simulation_start_time: float = 0.0
var _current_config: Dictionary = {}
var _start_requested: bool = false
## Người dùng nhấn A để bật/tắt chế độ quay video
var _record_mode_requested: bool = false

## Reference đến SimulationContainer node trong GameScene
var _simulation_container: Node2D = null
## Reference đến scene hiện tại đang chạy
var _current_simulation: Node = null

# ── Lifecycle ─────────────────────────────────────────────────────────────────
func _ready() -> void:
	# Lắng nghe signal hoàn thành từ EventBus
	EventBus.simulation_completed.connect(_on_simulation_completed)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_A:
				# A khi IDLE → bật/tắt chế độ quay video
				if current_state == State.IDLE:
					_record_mode_requested = not _record_mode_requested
					var msg: String = "[GameManager] Chế độ quay video: " + ("BẬT 🎥" if _record_mode_requested else "TẮT")
					print(msg)
					EventBus.hud_update_requested.emit("record_mode", _record_mode_requested)
			KEY_SPACE:
				# Space khi IDLE → bắt đầu game
				if current_state == State.IDLE and not _start_requested:
					_start_requested = true
					_start_simulation_flow()
			KEY_R:
				# R khi đang chạy → reset
				if current_state == State.RUNNING or current_state == State.COMPLETED:
					request_reset()

# ── Public API ────────────────────────────────────────────────────────────────

## Khởi tạo SimulationContainer reference (gọi từ GameScene._ready)
func initialize(simulation_container: Node2D) -> void:
	_simulation_container = simulation_container

## Load và bắt đầu một mode theo ID, với optional variant.
## variant_id: tên file variant (không có .json) trong variants/ thư mục của mode.
func start_mode(mode_id: String, variant_id: String = "") -> void:
	if not MODE_CONFIG_REGISTRY.has(mode_id):
		push_error("GameManager: mode_id '%s' không tồn tại trong registry" % mode_id)
		return

	current_mode_id = mode_id
	
	# Phase 5: Nếu có variant_id, load từ variants/ thư mục
	var config_path: String
	if not variant_id.is_empty():
		# Derive variant path: thay config.json → variants/{variant_id}.json
		var base_path: String = MODE_CONFIG_REGISTRY[mode_id]
		var dir: String = base_path.get_base_dir()
		config_path = dir + "/variants/" + variant_id + ".json"
		if not FileAccess.file_exists(config_path):
			push_warning("GameManager: variant '%s' not found at '%s', falling back to default config." % [variant_id, config_path])
			config_path = MODE_CONFIG_REGISTRY[mode_id]
		else:
			print("[GameManager] Loading variant: %s from %s" % [variant_id, config_path])
	else:
		config_path = MODE_CONFIG_REGISTRY[mode_id]
	
	var loader_script = load("res://Core/Base/ModeConfigLoader.gd")
	var loader = loader_script.new() as Object
	_current_config = loader.load_config(config_path)
	
	if _current_config.is_empty():
		push_error("GameManager: Lỗi load config cho mode '%s': %s" % [mode_id, loader.last_error])
		return
	
	# Phase 5: Inject variant_id vào config nếu chưa có
	if not variant_id.is_empty():
		var content_cfg: Dictionary = _current_config.get("content", {})
		if content_cfg.get("variant_id", "") == "":
			content_cfg["variant_id"] = variant_id
			_current_config["content"] = content_cfg
	
	# Áp dụng viewport settings từ config
	_apply_viewport_config(_current_config)
	
	_load_mode_scene(mode_id)

## Trả về config đang dùng (cho các hệ thống khác đọc nếu cần)
func get_current_config() -> Dictionary:
	return _current_config

## Yêu cầu reset simulation hiện tại (không reload scene)
func request_reset() -> void:
	if _current_simulation == null:
		return

	_set_state(State.RESETTING)
	_start_requested = false
	EventBus.simulation_reset.emit()

	# Gọi reset() trên simulation hiện tại
	if _current_simulation.has_method("reset"):
		_current_simulation.reset()

	_simulation_start_time = Time.get_ticks_msec() / 1000.0
	_set_state(State.RUNNING)

## Trả về thời gian đã chạy (giây)
func get_elapsed_time() -> float:
	if current_state != State.RUNNING:
		return 0.0
	return (Time.get_ticks_msec() / 1000.0) - _simulation_start_time

## Áp dụng cấu hình viewport từ config (màu nền, kích thước, fullscreen)
func _apply_viewport_config(config: Dictionary) -> void:
	var vp: Dictionary = config.get("viewport", {})
	var bg_color_str: String = vp.get("background_color", "#000000")
	RenderingServer.set_default_clear_color(Color(bg_color_str))
	
	# Áp dụng resolution từ config
	var res_arr: Array = vp.get("resolution", [])
	if res_arr.size() >= 2:
		var w: int = int(res_arr[0])
		var h: int = int(res_arr[1])
		if w > 0 and h > 0:
			# Bỏ qua resize nếu window đang ở embedded/editor mode
			if DisplayServer.window_get_size() != Vector2i(w, h):
				DisplayServer.window_set_size(Vector2i(w, h))
	
	# Fullscreen — chỉ khi chạy standalone (F5), không làm editor bị fullscreen
	var fullscreen: bool = vp.get("fullscreen", false)
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

# ── Private ───────────────────────────────────────────────────────────────────

func _load_mode_scene(mode_id: String) -> void:
	# Xóa simulation cũ nếu có
	if _current_simulation != null:
		_current_simulation.queue_free()
		_current_simulation = null

	var scene_path: String = _current_config.get("meta", {}).get("scene_path", "")
	if scene_path.is_empty():
		push_error("GameManager: config thiếu meta.scene_path cho mode '%s'" % mode_id)
		return
		
	var packed_scene: PackedScene = load(scene_path)
	if packed_scene == null:
		push_error("GameManager: không load được scene '%s'" % scene_path)
		return

	_current_simulation = packed_scene.instantiate()
	_simulation_container.add_child(_current_simulation)

	# Truyền config vào mode (nếu mode hỗ trợ set_config)
	if _current_simulation.has_method("set_config"):
		_current_simulation.set_config(_current_config)
	
	# Gọi setup() — KHÔNG start(), chờ người dùng nhấn R
	if _current_simulation.has_method("setup"):
		_current_simulation.setup()

	_simulation_start_time = Time.get_ticks_msec() / 1000.0
	_start_requested = false
	_set_state(State.IDLE)
	EventBus.simulation_ready.emit(mode_id)

	# Tự động bắt đầu nếu có tham số truyền vào từ command line
	if "--auto-start" in OS.get_cmdline_args() or "--auto-start" in OS.get_cmdline_user_args():
		_auto_start_flow()

func _auto_start_flow() -> void:
	await get_tree().create_timer(1.0).timeout
	if current_state == State.IDLE and not _start_requested:
		_start_requested = true
		_start_simulation_flow()

func _on_simulation_completed(mode_id: String, duration: float) -> void:
	_set_state(State.COMPLETED)

func _set_state(new_state: State) -> void:
	current_state = new_state

## Tiến trình bắt đầu game: Dùng flag record_mode thay vì tự động dò FFmpeg
func _start_simulation_flow() -> void:
	if _current_simulation == null:
		return

	var delay: float = 0.0
	if _record_mode_requested:
		delay = 1.5
		print("[GameManager] Đang kích hoạt quay video bằng FFmpeg. Trò chơi sẽ bắt đầu sau %.1f giây." % delay)
		EventBus.simulation_start_requested.emit(current_mode_id)
	else:
		# Không ghi hình, delay ngắn để regrow/spawn animation chạy mượt
		var auto_test_cfg: Dictionary = _current_config.get("auto_test", {})
		var trans_cfg: Dictionary = auto_test_cfg.get("transition", {})
		delay = trans_cfg.get("start_delay", 0.5)
		print("[GameManager] Chạy debug không quay video. Game bắt đầu sau %.1f giây." % delay)

	# Dùng tween để delay rồi start
	var start_tween: Tween = create_tween()
	start_tween.tween_interval(delay)
	start_tween.tween_callback(func():
		if _current_simulation.has_method("start"):
			_current_simulation.start()
		_simulation_start_time = Time.get_ticks_msec() / 1000.0
		_set_state(State.RUNNING)
		EventBus.simulation_started.emit(current_mode_id)
	)
