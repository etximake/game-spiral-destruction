## HUD.gd
## Hiển thị thông tin simulation trên CanvasLayer.
## Hoàn toàn decoupled — chỉ lắng nghe EventBus, không biết gì về game logic.
## Không bị ảnh hưởng bởi Camera2D shake/zoom vì nằm trong CanvasLayer.
extends Control

# ── Node references (tạo động trong _ready) ───────────────────────────────────
var _label_bottom_info: Label = null
var _label_title: Label = null

# ── State ─────────────────────────────────────────────────────────────────────
var _total_bricks: int = 0
var _destroyed_count: int = 0
var _elapsed_time: float = 0.0
var _is_running: bool = false
var _current_radius: float = 62.0

# ── Config (load từ GameManager) ──────────────────────────────────────────────
var _hud_title: String = "WILL THE BALLS GET TO CENTER"
var _hud_title_font_size: int = 42
var _hud_title_color: Color = Color.WHITE
var _hud_title_outline_color: Color = Color(0.0, 0.0, 0.0, 0.8)
var _hud_title_outline_size: int = 4
var _hud_info_font_size: int = 28
var _meter_pos: Vector2 = Vector2(1030, 200)
var _meter_size: Vector2 = Vector2(24, 300)
var _meter_radius_min: float = 15.0
var _meter_radius_max: float = 62.0
var _meter_border_width: int = 3

# ── Autoload shortcut ─────────────────────────────────────────────────────────
@onready var _event_bus: Node = get_node("/root/EventBus")

# ── Lifecycle ─────────────────────────────────────────────────────────────────
func _ready() -> void:
	_create_labels()
	_connect_signals()
	set_process_internal(true)
	# Deferred: load config sau khi GameScene._ready() gọi start_mode()
	call_deferred("_load_hud_config")

func _process(delta: float) -> void:
	if not _is_running:
		return
	_elapsed_time += delta

func _draw() -> void:
	# Vẽ thanh đo kích thước bóng (cấu hình từ hud.size_meter)
	var bar_pos: Vector2 = _meter_pos
	var bar_size: Vector2 = _meter_size
	
	# Vẽ viền ngoài của thanh đo
	draw_rect(Rect2(bar_pos, bar_size), Color(0.2, 0.2, 0.2, 0.8), false, float(_meter_border_width))
	
	# Tính tỷ lệ phần trăm bán kính bóng
	var r_min: float = _meter_radius_min
	var r_range: float = _meter_radius_max - r_min
	var t: float = clamp((_current_radius - r_min) / r_range, 0.0, 1.0)
	var fill_height: float = t * bar_size.y
	
	# Màu chuyển từ xanh lá -> vàng -> đỏ tùy theo kích thước
	var fill_color: Color = Color.GREEN
	if t > 0.6:
		fill_color = Color.RED
	elif t > 0.25:
		fill_color = Color.YELLOW
		
	# Vẽ vạch đầy (từ dưới lên)
	var fill_rect: Rect2 = Rect2(
		bar_pos.x + 3.0, 
		bar_pos.y + bar_size.y - fill_height + 3.0, 
		bar_size.x - 6.0, 
		max(0.0, fill_height - 6.0)
	)
	draw_rect(fill_rect, fill_color, true)

# ── Signal handlers ───────────────────────────────────────────────────────────

func _on_hud_update_requested(key: String, value: Variant) -> void:
	match key:
		"total":
			_total_bricks = int(value)
		"destroyed":
			_destroyed_count = int(value)
		"radius":
			_current_radius = float(value)
	
	_update_bottom_label()

func _on_ball_radius_changed(new_radius: float) -> void:
	_current_radius = new_radius
	_update_bottom_label()

func _on_simulation_started(_mode_id: String) -> void:
	_elapsed_time = 0.0
	_is_running = true

func _on_simulation_completed(_mode_id: String, _duration: float) -> void:
	_is_running = false

func _on_simulation_reset() -> void:
	_elapsed_time = 0.0
	_is_running = true
	_destroyed_count = 0
	_update_bottom_label()
	queue_redraw()

# ── Private ───────────────────────────────────────────────────────────────────


func _update_bottom_label() -> void:
	_label_bottom_info.text = "Ball radius: %.1f px  |  %d / %d" % [_current_radius, _destroyed_count, _total_bricks]
	queue_redraw()

func _create_labels() -> void:
	# Tiêu đề Shorts — Label (hỗ trợ outline đầy đủ, khác RichTextLabel)
	_label_title = Label.new()
	_label_title.text = _hud_title
	_label_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label_title.anchor_left = 0.0
	_label_title.anchor_right = 1.0
	_label_title.offset_left = 30.0
	_label_title.offset_right = -30.0
	_label_title.offset_top = 170.0
	_label_title.offset_bottom = 270.0
	
	# Cấu hình font + màu sắc + outline từ LabelSettings (đảm bảo hoạt động)
	var font: Font = load("res://font/Anton-Regular.ttf")
	var settings := LabelSettings.new()
	settings.font = font
	settings.font_size = _hud_title_font_size
	settings.font_color = _hud_title_color
	settings.outline_color = _hud_title_outline_color
	settings.outline_size = _hud_title_outline_size
	_label_title.label_settings = settings
	
	add_child(_label_title)

	# Bottom info — chính giữa, hiển thị radius + destroy
	_label_bottom_info = _make_label("Ball radius: 62.0 px  |  0 / 0", HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER)
	_label_bottom_info.anchor_left = 0.0
	_label_bottom_info.anchor_right = 1.0
	_label_bottom_info.anchor_top = 1.0
	_label_bottom_info.anchor_bottom = 1.0
	_label_bottom_info.offset_left = 30.0
	_label_bottom_info.offset_right = -30.0
	_label_bottom_info.offset_top = -340.0
	_label_bottom_info.offset_bottom = -300.0
	add_child(_label_bottom_info)

func _make_label(default_text: String, alignment: HorizontalAlignment) -> Label:
	var label: Label = Label.new()
	label.text = default_text
	label.horizontal_alignment = alignment

	var font: Font = load("res://font/Anton-Regular.ttf")
	var settings: LabelSettings = LabelSettings.new()
	settings.font = font
	settings.font_size = _hud_info_font_size
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

## Đọc cấu hình HUD từ GameManager (config-driven)
## Được gọi deferred để đảm bảo start_mode() đã load config xong
func _load_hud_config() -> void:
	var gm = get_node_or_null("/root/GameManager")
	if not gm or not gm.has_method("get_current_config"):
		return
	var cfg: Dictionary = gm.get_current_config()
	var hud_cfg: Dictionary = cfg.get("hud", {})
	if hud_cfg.is_empty():
		return  # Config chưa sẵn sàng, bỏ qua
	
	_hud_title = hud_cfg.get("title", _hud_title)
	_hud_title_font_size = hud_cfg.get("title_font_size", _hud_title_font_size)
	_hud_info_font_size = hud_cfg.get("info_font_size", _hud_info_font_size)
	
	# Title color & outline từ config
	var title_color_str: String = hud_cfg.get("title_color", "")
	if not title_color_str.is_empty():
		_hud_title_color = Color(title_color_str)
	var title_outline_color_str: String = hud_cfg.get("title_outline_color", "")
	if not title_outline_color_str.is_empty():
		_hud_title_outline_color = Color(title_outline_color_str)
	_hud_title_outline_size = hud_cfg.get("title_outline_size", _hud_title_outline_size)
	
	var meter: Dictionary = hud_cfg.get("size_meter", {})
	var pos_arr: Array = meter.get("position", [1030, 200])
	_meter_pos = Vector2(pos_arr[0], pos_arr[1])
	var size_arr: Array = meter.get("size", [24, 300])
	_meter_size = Vector2(size_arr[0], size_arr[1])
	_meter_radius_min = meter.get("radius_min", _meter_radius_min)
	_meter_radius_max = meter.get("radius_max", _meter_radius_max)
	_meter_border_width = meter.get("border_width", _meter_border_width)
	
	# Apply config vào labels đã tạo
	_label_title.text = _hud_title
	var s := LabelSettings.new()
	s.font = load("res://font/Anton-Regular.ttf")
	s.font_size = _hud_title_font_size
	s.font_color = _hud_title_color
	s.outline_color = _hud_title_outline_color
	s.outline_size = _hud_title_outline_size
	_label_title.label_settings = s
	
	for label in [_label_bottom_info]:
		if label and label.label_settings:
			label.label_settings.font_size = _hud_info_font_size
	
	queue_redraw()
