## HUD.gd
## Hiển thị thông tin simulation trên CanvasLayer.
## Hoàn toàn decoupled — chỉ lắng nghe EventBus, không biết gì về game logic.
## Không bị ảnh hưởng bởi Camera2D shake/zoom vì nằm trong CanvasLayer.
extends Control

# ── Node references (tạo động trong _ready) ───────────────────────────────────
var _label_radius: Label = null
var _label_destroyed: Label = null
var _label_timer: Label = null
var _label_fps: Label = null

# ── State ─────────────────────────────────────────────────────────────────────
var _total_bricks: int = 0
var _elapsed_time: float = 0.0
var _is_running: bool = false

# ── Autoload shortcut ─────────────────────────────────────────────────────────
@onready var _event_bus: Node = get_node("/root/EventBus")

# ── Lifecycle ─────────────────────────────────────────────────────────────────
func _ready() -> void:
	_create_labels()
	_connect_signals()

func _process(delta: float) -> void:
	if not _is_running:
		return
	_elapsed_time += delta
	_update_timer_label()
	# FPS monitor — task 8.3
	_label_fps.text = "FPS: %d" % Engine.get_frames_per_second()

# ── Signal handlers ───────────────────────────────────────────────────────────

func _on_hud_update_requested(key: String, value: Variant) -> void:
	match key:
		"total":
			_total_bricks = int(value)
		"destroyed":
			_label_destroyed.text = "%d / %d" % [int(value), _total_bricks]
		"radius":
			_label_radius.text = "Ball radius: %.1f px" % float(value)

func _on_ball_radius_changed(new_radius: float) -> void:
	_label_radius.text = "Ball radius: %.1f px" % new_radius

func _on_simulation_started(_mode_id: String) -> void:
	_elapsed_time = 0.0
	_is_running = true

func _on_simulation_completed(_mode_id: String, _duration: float) -> void:
	_is_running = false

func _on_simulation_reset() -> void:
	_elapsed_time = 0.0
	_is_running = true
	_label_destroyed.text = "0 / %d" % _total_bricks

# ── Private ───────────────────────────────────────────────────────────────────

func _update_timer_label() -> void:
	var minutes: int = int(_elapsed_time) / 60
	var seconds: int = int(_elapsed_time) % 60
	_label_timer.text = "%02d:%02d" % [minutes, seconds]

func _create_labels() -> void:
	# Timer — trên trái
	_label_timer = _make_label("00:00", HorizontalAlignment.HORIZONTAL_ALIGNMENT_LEFT)
	_label_timer.anchor_left = 0.0
	_label_timer.anchor_right = 0.0
	_label_timer.offset_left = 20.0
	_label_timer.offset_top = 20.0
	_label_timer.offset_right = 220.0
	_label_timer.offset_bottom = 60.0
	add_child(_label_timer)

	# Destroyed counter — trên phải
	_label_destroyed = _make_label("0 / 0", HorizontalAlignment.HORIZONTAL_ALIGNMENT_RIGHT)
	_label_destroyed.anchor_left = 1.0
	_label_destroyed.anchor_right = 1.0
	_label_destroyed.offset_left = -220.0
	_label_destroyed.offset_top = 20.0
	_label_destroyed.offset_right = -20.0
	_label_destroyed.offset_bottom = 60.0
	add_child(_label_destroyed)

	# Ball radius — dưới giữa
	_label_radius = _make_label("Ball radius: 54.0 px", HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER)
	_label_radius.anchor_left = 0.0
	_label_radius.anchor_right = 1.0
	_label_radius.anchor_top = 1.0
	_label_radius.anchor_bottom = 1.0
	_label_radius.offset_left = 0.0
	_label_radius.offset_top = -60.0
	_label_radius.offset_right = 0.0
	_label_radius.offset_bottom = -20.0
	add_child(_label_radius)

	# FPS — trên trái, dưới timer (task 8.3)
	_label_fps = _make_label("FPS: 60", HorizontalAlignment.HORIZONTAL_ALIGNMENT_LEFT)
	_label_fps.anchor_left = 0.0
	_label_fps.anchor_right = 0.0
	_label_fps.offset_left = 20.0
	_label_fps.offset_top = 65.0
	_label_fps.offset_right = 180.0
	_label_fps.offset_bottom = 100.0
	_label_fps.modulate = Color(0.7, 1.0, 0.7, 0.8)  # Xanh nhạt để phân biệt
	add_child(_label_fps)

func _make_label(default_text: String, alignment: HorizontalAlignment) -> Label:
	var label: Label = Label.new()
	label.text = default_text
	label.horizontal_alignment = alignment

	var settings: LabelSettings = LabelSettings.new()
	settings.font_size = 28
	settings.font_color = Color.WHITE
	settings.shadow_color = Color(0.0, 0.0, 0.0, 0.8)
	settings.shadow_offset = Vector2(2.0, 2.0)
	settings.shadow_size = 2
	label.label_settings = settings

	return label

func _connect_signals() -> void:
	_event_bus.hud_update_requested.connect(_on_hud_update_requested)
	_event_bus.ball_radius_changed.connect(_on_ball_radius_changed)
	_event_bus.simulation_started.connect(_on_simulation_started)
	_event_bus.simulation_completed.connect(_on_simulation_completed)
	_event_bus.simulation_reset.connect(_on_simulation_reset)
