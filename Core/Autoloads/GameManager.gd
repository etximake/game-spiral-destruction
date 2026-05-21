## GameManager.gd
## Singleton — State machine trung tâm + Mode registry.
## Quản lý vòng đời simulation: IDLE → RUNNING → COMPLETED → RESETTING → RUNNING
extends Node

# ── Enum trạng thái ───────────────────────────────────────────────────────────
enum State {
	IDLE,       # Chờ bắt đầu (scene vừa load)
	RUNNING,    # Simulation đang chạy
	COMPLETED,  # Win condition đạt được, đang hiện end screen
	RESETTING,  # Đang reset (tức thì, không reload scene)
}

# ── Mode Registry ─────────────────────────────────────────────────────────────
## Đăng ký tất cả simulation modes ở đây.
## Key: mode_id (String), Value: đường dẫn scene
const MODE_REGISTRY: Dictionary = {
	"spiral": "res://Modes/SpiralDestruction/SpiralMode.tscn",
}

# ── State ─────────────────────────────────────────────────────────────────────
var current_state: State = State.IDLE
var current_mode_id: String = ""
var _simulation_start_time: float = 0.0

## Reference đến SimulationContainer node trong GameScene
var _simulation_container: Node2D = null
## Reference đến scene hiện tại đang chạy
var _current_simulation: Node = null

# ── Lifecycle ─────────────────────────────────────────────────────────────────
func _ready() -> void:
	# Lắng nghe signal hoàn thành từ EventBus
	EventBus.simulation_completed.connect(_on_simulation_completed)

func _input(event: InputEvent) -> void:
	# Phím R: reset nhanh trong lúc quay video
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.keycode == KEY_R and event.pressed):
		if current_state == State.RUNNING or current_state == State.COMPLETED:
			request_reset()

# ── Public API ────────────────────────────────────────────────────────────────

## Khởi tạo SimulationContainer reference (gọi từ GameScene._ready)
func initialize(simulation_container: Node2D) -> void:
	_simulation_container = simulation_container

## Load và bắt đầu một mode theo ID
func start_mode(mode_id: String) -> void:
	if not MODE_REGISTRY.has(mode_id):
		push_error("GameManager: mode_id '%s' không tồn tại trong registry" % mode_id)
		return

	current_mode_id = mode_id
	_load_mode_scene(mode_id)

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

# ── Private ───────────────────────────────────────────────────────────────────

func _load_mode_scene(mode_id: String) -> void:
	# Xóa simulation cũ nếu có
	if _current_simulation != null:
		_current_simulation.queue_free()
		_current_simulation = null

	var scene_path: String = MODE_REGISTRY[mode_id]
	var packed_scene: PackedScene = load(scene_path)
	if packed_scene == null:
		push_error("GameManager: không load được scene '%s'" % scene_path)
		return

	_current_simulation = packed_scene.instantiate()
	_simulation_container.add_child(_current_simulation)

	# Gọi setup() rồi start()
	if _current_simulation.has_method("setup"):
		_current_simulation.setup()
	if _current_simulation.has_method("start"):
		_current_simulation.start()

	_simulation_start_time = Time.get_ticks_msec() / 1000.0
	_set_state(State.RUNNING)
	EventBus.simulation_started.emit(mode_id)

func _on_simulation_completed(mode_id: String, duration: float) -> void:
	_set_state(State.COMPLETED)

func _set_state(new_state: State) -> void:
	current_state = new_state
