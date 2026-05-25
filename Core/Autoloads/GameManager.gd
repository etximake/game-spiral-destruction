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
			KEY_SPACE:
				# Space khi IDLE → bắt đầu game sau delay
				if current_state == State.IDLE:
					_start_with_delay()
			KEY_R:
				# R khi đang chạy → reset
				if current_state == State.RUNNING or current_state == State.COMPLETED:
					request_reset()

# ── Public API ────────────────────────────────────────────────────────────────

## Khởi tạo SimulationContainer reference (gọi từ GameScene._ready)
func initialize(simulation_container: Node2D) -> void:
	_simulation_container = simulation_container

## Load và bắt đầu một mode theo ID
func start_mode(mode_id: String) -> void:
	if not MODE_CONFIG_REGISTRY.has(mode_id):
		push_error("GameManager: mode_id '%s' không tồn tại trong registry" % mode_id)
		return

	current_mode_id = mode_id
	
	# Load config từ JSON
	var config_path: String = MODE_CONFIG_REGISTRY[mode_id]
	var loader_script = load("res://Core/Base/ModeConfigLoader.gd")
	var loader = loader_script.new() as Object
	_current_config = loader.load_config(config_path)
	
	if _current_config.is_empty():
		push_error("GameManager: Lỗi load config cho mode '%s': %s" % [mode_id, loader.last_error])
		return
	
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

## Áp dụng cấu hình viewport từ config (màu nền, kích thước, v.v.)
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
	_set_state(State.IDLE)
	EventBus.simulation_ready.emit(mode_id)

func _on_simulation_completed(mode_id: String, duration: float) -> void:
	_set_state(State.COMPLETED)

func _set_state(new_state: State) -> void:
	current_state = new_state

## Bắt đầu game sau delay (gọi khi nhấn R ở trạng thái IDLE)
func _start_with_delay() -> void:
	if _current_simulation == null:
		return
	# Đọc start_delay từ config
	var auto_test_cfg: Dictionary = _current_config.get("auto_test", {})
	var trans_cfg: Dictionary = auto_test_cfg.get("transition", {})
	var delay: float = trans_cfg.get("start_delay", 0.5)
	
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
