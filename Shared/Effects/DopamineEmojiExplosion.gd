## DopamineEmojiExplosion.gd (v8 — Spiral Galaxy)
## Hiệu ứng chiến thắng: emoji xoáy hình soắn ốc phát triển từ trong ra ngoài.
## Kích thước to dần theo bán kính. Tối ưu performance.
extends Node2D

# ── Config ────────────────────────────────────────────────────────────────────
var _spiral_center := Vector2(540.0, 960.0)
var _emoji_char: String = "\uD83D\uDE0A"
var _emoji_size_min: float = 60.0
var _emoji_size_max: float = 200.0

# ── State ─────────────────────────────────────────────────────────────────────
var _callback: Callable
var _total_duration: float = 3.5
var _phase_timer: float = 0.0
var _emoji_pool: Array[Label] = []

# Parallel arrays
var _target_angles: Array[float] = []
var _target_radii: Array[float] = []
var _sizes: Array[float] = []
var _spiral_progress: Array[float] = []  # 0.0 → 1.0, dùng để xác định thứ tự xuất hiện

const POOL_SIZE: int = 250
const SPIRAL_TURNS: float = 5.0

func _ready() -> void:
	z_index = 10
	z_as_relative = false
	set_process(false)

func _load_config() -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.has_method("get_current_config"):
		var cfg: Dictionary = gm.get_current_config()
		var we: Dictionary = cfg.get("win_effect", {})
		var sc: Dictionary = cfg.get("spiral", {})
		var center_arr: Array = sc.get("center", [540.0, 960.0])
		_spiral_center = Vector2(center_arr[0], center_arr[1])
		_emoji_char = we.get("emoji", _emoji_char)
		var size_arr: Array = we.get("emoji_size", [200, 200])
		var base_size: float = float(size_arr[0])
		_emoji_size_min = base_size * 0.3
		_emoji_size_max = base_size * 1.0

func _init_pool() -> void:
	if _emoji_pool.size() > 0:
		return

	_load_config()

	var viewport_size: Vector2 = get_viewport_rect().size
	if viewport_size == Vector2.ZERO:
		viewport_size = Vector2(1080, 1920)
	# Bán kính spiral phủ vừa màn hình
	var max_radius: float = viewport_size.length() * 0.45

	# Chia emoji thành 5 nhóm kích thước để dùng chung LabelSettings
	var size_groups: Array[Dictionary] = [
		{"size": 60,  "font": 40,  "count": 50},
		{"size": 90,  "font": 55,  "count": 50},
		{"size": 120, "font": 70,  "count": 50},
		{"size": 160, "font": 85,  "count": 50},
		{"size": 200, "font": 100, "count": 50},
	]

	var pool_idx: int = 0
	for group in size_groups:
		var s: float = group.size
		var fs: int = group.font
		var settings := LabelSettings.new()
		settings.font_size = fs

		for _j in group.count:
			if pool_idx >= POOL_SIZE:
				break

			var label := Label.new()
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			label.custom_minimum_size = Vector2(s, s)
			label.pivot_offset = Vector2(s * 0.5, s * 0.5)
			label.label_settings = settings
			label.z_index = 8
			label.z_as_relative = false
			label.text = _emoji_char
			label.visible = false
			add_child(label)

			_emoji_pool.append(label)
			_sizes.append(s)

			# Vị trí trên đường xoắn ốc (lưu góc + bán kính để xoay động)
			var t: float = float(pool_idx) / float(POOL_SIZE)  # 0→1
			var angle: float = t * SPIRAL_TURNS * TAU
			var radius: float = t * max_radius
			_target_angles.append(angle)
			_target_radii.append(radius)
			_spiral_progress.append(t)

			pool_idx += 1

func play_effect(_spiral_points: PackedVector2Array, callback: Callable) -> void:
	_init_pool()
	_callback = callback
	_phase_timer = 0.0

	# Reset tất cả về tâm, ẩn, chờ reveal theo spiral
	for i in _emoji_pool.size():
		var label: Label = _emoji_pool[i]
		label.position = _spiral_center - Vector2(_sizes[i] * 0.5, _sizes[i] * 0.5)
		label.scale = Vector2.ZERO
		label.modulate.a = 0.0
		label.rotation = randf_range(0.0, TAU)
		label.visible = true

	set_process(true)

func _process(delta: float) -> void:
	_phase_timer += delta

	# 0-1.5s: reveal spiral từ trong ra ngoài + xoay kim đồng hồ
	# 1.5-2.5s: tiếp tục xoay, giữ nguyên
	# 2.5-3.5s: fade out
	var reveal_progress: float = clamp(_phase_timer / 1.5, 0.0, 1.0)
	var fade_progress: float = clamp((_phase_timer - 2.5) / 1.0, 0.0, 1.0)

	# Ease-out cho reveal: nhanh đầu, chậm cuối
	var reveal_eased: float = 1.0 - pow(1.0 - reveal_progress, 1.5)

	# Clockwise rotation — emoji trong xoay nhanh hơn ngoài (vortex)
	var base_rot_speed: float = 4.0  # rad/s
	var rotation_offset: float = -_phase_timer * base_rot_speed  # âm = clockwise

	for i in _emoji_pool.size():
		var label: Label = _emoji_pool[i]
		if not label.visible:
			continue

		var t: float = _spiral_progress[i]  # 0→1

		# Chỉ hiện emoji khi đến lượt theo spiral_progress
		if t <= reveal_eased:
			# Pop-in scale
			var local_age: float = (reveal_eased - t) / 0.15  # 0.15s để pop mỗi emoji
			var pop_scale: float = clamp(local_age, 0.0, 1.0)
			pop_scale = -pop_scale * (pop_scale - 2.0)  # ease-out quad

			label.scale = Vector2(pop_scale, pop_scale)
			label.modulate.a = pop_scale

			# Vị trí xoay theo kim đồng hồ — trong nhanh hơn ngoài
			var angular_factor: float = 1.0 - t * 0.8  # 1.0 (tâm) → 0.2 (rìa)
			var rotated_angle: float = _target_angles[i] + rotation_offset * angular_factor
			var radius: float = _target_radii[i]
			var target: Vector2 = _spiral_center + Vector2(cos(rotated_angle), sin(rotated_angle)) * radius
			var s: float = _sizes[i]
			var move_t: float = clamp(local_age, 0.0, 1.0)
			move_t = -move_t * (move_t - 2.0)  # ease-out quad
			label.position = _spiral_center.lerp(target - Vector2(s * 0.5, s * 0.5), move_t)

			# Xoay label theo hướng chuyển động
			label.rotation = rotated_angle + PI * 0.5

		# Fade out
		if fade_progress > 0.0:
			label.modulate.a = clamp(1.0 - fade_progress, 0.0, 1.0)

	if _phase_timer > _total_duration:
		_finish_effect()

func _finish_effect() -> void:
	set_process(false)
	for label in _emoji_pool:
		label.visible = false
	if _callback:
		_callback.call()
	queue_free()