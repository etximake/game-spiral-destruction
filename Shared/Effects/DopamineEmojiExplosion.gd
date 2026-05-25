## DopamineEmojiExplosion.gd (v5 — Chaotic Burst)
## Hiệu ứng chiến thắng: emoji sinh hỗn loạn, phát triển từ trong ra ngoài,
## tổng thời gian 3 giây.
extends Node2D

# ── Config ────────────────────────────────────────────────────────────────────
var _spiral_center := Vector2(540.0, 960.0)
var _emoji_char: String = "\uD83D\uDE0A"
var _emoji_font_size: int = 48
var _emoji_size_px: float = 60.0

func _load_config() -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.has_method("get_current_config"):
		var cfg: Dictionary = gm.get_current_config()
		var we: Dictionary = cfg.get("win_effect", {})
		var sc: Dictionary = cfg.get("spiral", {})
		var center_arr: Array = sc.get("center", [540.0, 960.0])
		_spiral_center = Vector2(center_arr[0], center_arr[1])
		_emoji_char = we.get("emoji", _emoji_char)
		_emoji_font_size = we.get("font_size", 80)

# ── State ─────────────────────────────────────────────────────────────────────
var _callback: Callable
var _max_radius: float = 600.0
var _total_duration: float = 3.0
var _phase_timer: float = 0.0
var _emoji_pool: Array[Label] = []
var _active_pool: Array[Label] = []
var _pool_index: int = 0
var _spawn_timer: float = 0.0
var _spawn_interval: float = 0.05  # Spawn mỗi 0.05s (20 ticks/s)

func _ready() -> void:
	z_index = 10
	z_as_relative = false
	# Pre-allocate 200 labels — đủ cho 3 giây hỗn loạn
	var total_emoji: int = 200
	for i in total_emoji:
		var label := Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.custom_minimum_size = Vector2(_emoji_size_px, _emoji_size_px)
		label.pivot_offset = Vector2(_emoji_size_px * 0.5, _emoji_size_px * 0.5)
		label.z_index = 8
		label.z_as_relative = false
		label.scale = Vector2.ZERO
		label.visible = false
		add_child(label)
		_emoji_pool.append(label)

func play_effect(_spiral_points: PackedVector2Array, callback: Callable) -> void:
	_load_config()
	_callback = callback
	_phase_timer = 0.0
	_spawn_timer = 0.0
	_pool_index = 0
	
	# Cập nhật pool với emoji + font từ config
	var settings := LabelSettings.new()
	settings.font_size = _emoji_font_size
	for label in _emoji_pool:
		label.text = _emoji_char
		label.label_settings = settings
		label.visible = false
		label.scale = Vector2.ZERO
		label.modulate.a = 1.0
	_active_pool.clear()
	
	# Ước tính bán kính ngoài cùng
	if _spiral_points.size() > 0:
		var max_dist: float = 0.0
		for p in _spiral_points:
			var d: float = p.distance_squared_to(_spiral_center)
			if d > max_dist: max_dist = d
		_max_radius = sqrt(max_dist)
	
	set_process(true)

func _process(delta: float) -> void:
	_phase_timer += delta
	_spawn_timer += delta
	
	# Spawn ngẫu nhiên theo interval
	while _spawn_timer >= _spawn_interval and _pool_index < _emoji_pool.size():
		_spawn_timer -= _spawn_interval
		# Mỗi tick spawn 2-5 emoji ngẫu nhiên
		var count: int = randi_range(2, 5)
		for _i in count:
			if _pool_index >= _emoji_pool.size():
				break
			_spawn_random_emoji()
	
	# Update active emojis
	var remaining: Array[Label] = []
	for label in _active_pool:
		if not is_instance_valid(label):
			continue
		var age: float = _phase_timer - label.get_meta("spawn_time", 0.0)
		if age > 1.2:
			label.visible = false
			label.scale = Vector2.ZERO
			continue
		
		if age < 0.25:
			# Pop in nhanh + hơi overshoot
			var t: float = age / 0.25
			var pop: float = -t * (t - 2.0)  # Ease out quad
			label.scale = Vector2(pop, pop)
			label.modulate.a = t
		elif age > 1.0:
			# Fade out
			var t: float = (1.2 - age) / 0.2
			label.modulate.a = clamp(t, 0.0, 1.0)
		else:
			label.scale = Vector2(1.0, 1.0)
			label.modulate.a = 1.0
		
		remaining.append(label)
	_active_pool = remaining
	
	# Kết thúc
	if _phase_timer > _total_duration + 0.5 and _active_pool.is_empty():
		_finish_effect()

## Spawn 1 emoji tại vị trí ngẫu nhiên trong bán kính cho phép
func _spawn_random_emoji() -> void:
	var label: Label = _emoji_pool[_pool_index]
	_pool_index += 1
	
	# Bán kính tối đa tăng dần theo thời gian (0 → _max_radius)
	var radius_max: float = (_phase_timer / _total_duration) * _max_radius * 1.05
	
	# Random góc + bán kính trong phạm vi cho phép
	var angle: float = randf_range(0.0, TAU)
	var radius: float = randf_range(0.0, radius_max)
	
	# Đôi khi cho emoji lệch ra xa hơn một chút (10% ngẫu nhiên)
	if randf() < 0.1:
		radius = radius_max * 1.2
	
	label.position = _spiral_center + Vector2(cos(angle), sin(angle)) * radius - Vector2(_emoji_size_px * 0.5, _emoji_size_px * 0.5)
	label.rotation = randf_range(0.0, TAU)  # Xoay ngẫu nhiên
	label.visible = true
	label.scale = Vector2.ZERO
	label.set_meta("spawn_time", _phase_timer)
	_active_pool.append(label)

func _finish_effect() -> void:
	set_process(false)
	for label in _emoji_pool:
		if is_instance_valid(label):
			label.queue_free()
	_emoji_pool.clear()
	_active_pool.clear()
	if _callback.is_valid():
		_callback.call()
	queue_free()