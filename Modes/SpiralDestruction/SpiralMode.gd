## SpiralMode.gd
## Scene controller cho Spiral Destruction mode.
## Implements SimulationBase interface.
## Hỗ trợ auto-test: chạy lần lượt 5 ngưỡng bán kính ball.
extends "res://Core/Base/SimulationBase.gd"

# ── Node references ───────────────────────────────────────────────────────────
@onready var map_controller: Node = $SpiralMapController
@onready var render_controller: Node = $SpiralRenderController
@onready var ball: Node2D = $Ball
@onready var center_glow: PointLight2D = $CenterGlow
@onready var screen_shake: Node = $ScreenShake

# ── Autoload shortcuts ────────────────────────────────────────────────────────
@onready var _event_bus: Node = get_node("/root/EventBus")
@onready var _object_pool: Node = get_node("/root/ObjectPool")

# ── Config shortcuts (set từ _config khi setup) ───────────────────────────────
var _auto_test_cfg: Dictionary = {}
var _win_effect_cfg: Dictionary = {}
var _test_radii: Array = []
var _test_speeds: Array = []
var _test_timeout: float = 20.0
var _stuck_no_progress: float = 3.0
var _out_of_bounds_delay: float = 1.5
var _out_of_bounds_margin: float = 50.0
var _out_of_bounds_radius_factor: float = 1.5
var _burst_particle_count: int = 8
var _center_glow_burst: float = 8.0

# ── Auto-test ─────────────────────────────────────────────────────────────────
var _current_test_index: int = 0
var _auto_test_enabled: bool = true
var _test_timer: float = 0.0

# ── Stuck Detection ───────────────────────────────────────────────────────────
var _bounce_count: int = 0
var _min_dist_to_center: float = INF
var _no_progress_timer: float = 0.0
var _is_transitioning: bool = false

# ── State ─────────────────────────────────────────────────────────────────────
var _destroyed_count: int = 0
var _destroyed_ids: Array[int] = []
var _is_running: bool = false
var _glow_time: float = 0.0

# ── Lifecycle ─────────────────────────────────────────────────────────────────

## Gọi bởi GameManager để truyền config (từ JSON)
func set_config(config: Dictionary) -> void:
	_config = config
	
	# Trích xuất config shortcuts
	_auto_test_cfg = config.get("auto_test", {})
	_win_effect_cfg = config.get("win_effect", {})
	
	var test_list: Array = _auto_test_cfg.get("tests", [])
	_test_radii.clear()
	_test_speeds.clear()
	for t in test_list:
		if t is Dictionary:
			_test_radii.append(t.get("radius", 45.0))
			_test_speeds.append(t.get("speed", 320.0))
	
	_test_timeout = _auto_test_cfg.get("timeout", 20.0)
	_stuck_no_progress = _auto_test_cfg.get("stuck_no_progress_seconds", 3.0)
	_out_of_bounds_delay = _auto_test_cfg.get("out_of_bounds_delay", 1.5)
	_out_of_bounds_margin = _auto_test_cfg.get("out_of_bounds_margin", 50.0)
	_out_of_bounds_radius_factor = _auto_test_cfg.get("out_of_bounds_radius_factor", 1.5)
	_center_glow_burst = _win_effect_cfg.get("center_glow_burst", 8.0)
	
	var debris_cfg: Dictionary = config.get("debris", {})
	_burst_particle_count = debris_cfg.get("num_burst_particles", 8)
	
	# Truyền config xuống subsystems
	map_controller.set_config(config)
	render_controller.set_config(config)
	if ball.has_method("set_ball_config"):
		ball.set_ball_config(config.get("ball", {}), config.get("spiral", {}))
	ball.set("map_controller", map_controller)

func _process(delta: float) -> void:
	if not _is_running:
		return

	# Center glow pulse
	_glow_time += delta
	center_glow.energy = 1.4 + 0.6 * sin(_glow_time * PI)

	# Auto-test stuck detection
	if _auto_test_enabled and not _is_transitioning:
		_test_timer += delta
		
		# Tính khoảng cách bóng tới tâm
		var center: Vector2 = map_controller.SPIRAL_CENTER
		var current_dist: float = ball.global_position.distance_to(center)
		
		# Nếu bóng tiến gần tâm hơn tối thiểu 5px, reset no progress timer
		if current_dist < _min_dist_to_center - 5.0:
			_min_dist_to_center = current_dist
			_no_progress_timer = 0.0
		else:
			_no_progress_timer += delta

		# Phát hiện ball bay ra ngoài line
		if _test_timer > _out_of_bounds_delay and current_dist > map_controller.outer_radius * _out_of_bounds_radius_factor + _out_of_bounds_margin:
			print("[AUTO-TEST] 🚨 OUT OF BOUNDS! Ball bay ra ngoài miệng spiral tại khoảng cách %.1f px" % current_dist)
			_transition_to_next_test(true)

		# Kẹt trong N giây không tiến triển hoặc timeout
		if _no_progress_timer >= _stuck_no_progress or _test_timer >= _test_timeout:
			_transition_to_next_test(true)

# ── SimulationBase interface ──────────────────────────────────────────────────

func setup() -> void:
	map_controller.generate()
	render_controller.setup(map_controller)
	ball.set("map_controller", map_controller)

	# Auto-test: set bán kính ban đầu theo ngưỡng hiện tại
	if _auto_test_enabled and _test_radii.size() > 0:
		var test_radius: float = _test_radii[_current_test_index]
		var test_speed: float = _test_speeds[_current_test_index]
		ball.set("radius", test_radius)
		ball.set("ball_speed", test_speed)
		ball.set("shrink_enabled", false)
		print("[AUTO-TEST] Bắt đầu test #1 — Ball radius: %.1f px, speed: %.1f px/s" % [test_radius, test_speed])
	else:
		var ball_cfg: Dictionary = _config.get("ball", {})
		ball.set("radius", ball_cfg.get("initial_radius", 62.0))
		ball.set("ball_speed", ball_cfg.get("base_speed", 600.0))
		ball.set("shrink_enabled", true)

	_place_ball_at_spawn()
	_connect_signals()
	_create_end_emoji()

	_event_bus.hud_update_requested.emit("total", map_controller.total_triangles)
	_event_bus.hud_update_requested.emit("destroyed", 0)
	_event_bus.ball_radius_changed.emit(ball.get("radius"))
	
	render_controller.play_spawn_animation()

	_bounce_count = 0
	_min_dist_to_center = INF
	_no_progress_timer = 0.0
	_is_transitioning = false

func start() -> void:
	_is_running = true
	ball.set("active", true)

func reset() -> void:
	_is_running = false
	_destroyed_count = 0
	_destroyed_ids.clear()
	_glow_time = 0.0
	_test_timer = 0.0
	_bounce_count = 0
	_min_dist_to_center = INF
	_no_progress_timer = 0.0
	_is_transitioning = false

	ball.call("reset")
	
	if _auto_test_enabled and _test_radii.size() > 0:
		var test_radius: float = _test_radii[_current_test_index]
		var test_speed: float = _test_speeds[_current_test_index]
		ball.set("radius", test_radius)
		ball.set("ball_speed", test_speed)
		ball.set("shrink_enabled", false)
	else:
		var ball_cfg: Dictionary = _config.get("ball", {})
		ball.set("radius", ball_cfg.get("initial_radius", 62.0))
		ball.set("ball_speed", ball_cfg.get("base_speed", 600.0))
		ball.set("shrink_enabled", true)

	_place_ball_at_spawn()
	ball.set("active", false)

	map_controller.restore_all()
	render_controller.play_spawn_animation()
	map_controller._build_spatial_grid()

	# Restore modulate
	modulate = Color.WHITE
	render_controller.modulate = Color.WHITE
	ball.modulate = Color.WHITE
	if ball.has_node("Trail"):
		ball.get_node("Trail").modulate = Color.WHITE

	if _emoji_label:
		_emoji_label.visible = true

	_event_bus.hud_update_requested.emit("destroyed", 0)
	_event_bus.ball_radius_changed.emit(ball.get("radius"))

	_is_running = true
	ball.set("active", true)

func on_completed() -> void:
	_is_running = false
	ball.set("active", false)
	if _emoji_label:
		_emoji_label.visible = false

	if DisplayServer.get_name() == "headless":
		if _auto_test_enabled:
			_transition_to_next_test(false)
		else:
			_emit_completed()
		return

	# Win burst — phun debris từ vị trí emoji
	var end_pos: Vector2 = map_controller.spiral_end_position
	for i: int in _burst_particle_count:
		var offset: Vector2 = Vector2(randf_range(-20.0, 20.0), randf_range(-20.0, 20.0))
		var burst_color: Color = Color.from_hsv(float(i) / float(_burst_particle_count), 1.0, 1.0)
		_object_pool.get_debris(end_pos + offset, burst_color)

	# Center glow burst
	var tween: Tween = create_tween()
	tween.tween_property(center_glow, "energy", _center_glow_burst, 0.2)
	tween.tween_interval(1.0)
	tween.tween_property(center_glow, "energy", 0.0, 0.5)

	# Chạy hiệu ứng dopamine emoji explosion
	var explosion_script = load("res://Shared/Effects/DopamineEmojiExplosion.gd")
	var explosion = explosion_script.new()
	add_child(explosion)
	
	# Fade dần spiral line + triangles + ball + trail trong lúc hiệu ứng chạy
	var fade_tween: Tween = create_tween().set_parallel(true)
	fade_tween.tween_property(render_controller, "modulate:a", 0.0, 2.5).set_ease(Tween.EASE_IN)
	fade_tween.tween_property(ball, "modulate:a", 0.0, 2.5).set_ease(Tween.EASE_IN)
	# Trail có top_level=true nên cần fade trực tiếp
	if ball.has_node("Trail"):
		fade_tween.tween_property(ball.get_node("Trail"), "modulate:a", 0.0, 2.5).set_ease(Tween.EASE_IN)

	var callback = func():
		if _auto_test_enabled:
			_transition_to_next_test(false)
		else:
			var scene_fade: Tween = create_tween()
			scene_fade.tween_property(self, "modulate:a", 0.0, 1.5)
			scene_fade.tween_callback(_emit_completed)

	explosion.play_effect(map_controller.spiral_points, callback)

# ── Signal handlers ───────────────────────────────────────────────────────────

func _on_brick_destroyed(brick_id: int, world_position: Vector2, color: Color) -> void:
	if not _is_running:
		return
	render_controller.hide_triangle(brick_id)
	map_controller.destroy_triangle(brick_id)
	_object_pool.get_debris(world_position, color)
	if not _destroyed_ids.has(brick_id):
		_destroyed_ids.append(brick_id)
	_destroyed_count += 1
	_event_bus.hud_update_requested.emit("destroyed", _destroyed_count)

func _on_ball_bounced(_position: Vector2, _normal: Vector2) -> void:
	if not _is_running:
		return
	_bounce_count += 1
	# Hiệu ứng rung màn hình đã được tắt theo yêu cầu người dùng
	# if screen_shake.has_method("shake"):
	# 	var intensity: float = ball.get("radius") / 37.0 * 3.0
	# 	screen_shake.call("shake", intensity)

# ── Private ───────────────────────────────────────────────────────────────────

func _place_ball_at_spawn() -> void:
	# 1. Tìm vị trí Y cao nhất (đỉnh) của spiral
	var min_y: float = INF
	for p in map_controller.spiral_points:
		if p.y < min_y:
			min_y = p.y
			
	# 2. Điểm xuất phát: X ngang với miệng (spawn_point.x + 20), Y ngang với đỉnh (min_y)
	var spawn_point: Vector2 = map_controller.spiral_points[0]
	ball.global_position = Vector2(spawn_point.x + 20.0, min_y)

	# Reset trail to new spawn position immediately to avoid misalignment
	if ball.has_method("reset_trail"):
		ball.call("reset_trail")

	# 3. Hướng ban đầu: hướng từ điểm spawn vào tâm miệng của spiral (spawn_point.x - 40, spawn_point.y)
	var target_mouth: Vector2 = Vector2(spawn_point.x - 40.0, spawn_point.y)
	var initial_dir: Vector2 = (target_mouth - ball.global_position).normalized()
	var current_speed: float = ball.get("ball_speed")
	ball.set("velocity", initial_dir * current_speed)

func _connect_signals() -> void:
	if not _event_bus.brick_destroyed.is_connected(_on_brick_destroyed):
		_event_bus.brick_destroyed.connect(_on_brick_destroyed)
	if not _event_bus.ball_bounced.is_connected(_on_ball_bounced):
		_event_bus.ball_bounced.connect(_on_ball_bounced)

# ── Auto-test ─────────────────────────────────────────────────────────────────

## Thực hiện hiệu ứng chuyển cảnh và chạy test mới (theo GDD 3.6)
func _transition_to_next_test(stuck: bool) -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	_is_running = false
	ball.set("active", false)

	var current_radius: float = _test_radii[_current_test_index] if _current_test_index < _test_radii.size() else 0.0
	
	if stuck:
		print("[AUTO-TEST] ❌ STUCK! Radius %.1f bị kẹt — không đến được emoji trong %.1fs" % [current_radius, _test_timer])
	else:
		print("[AUTO-TEST] ✅ WIN! Radius %.1f đã chạm emoji! (%.1fs)" % [current_radius, _test_timer])
		# WIN → kết thúc ngay, không chạy test tiếp theo
		print("[AUTO-TEST] ══════════════════════════════════════")
		print("[AUTO-TEST] 🏆 Chiến thắng! Ball radius %.1f đã đến được emoji!" % current_radius)
		print("[AUTO-TEST] Radii tested: %s" % str(_test_radii))
		print("[AUTO-TEST] ══════════════════════════════════════")
		_auto_test_enabled = false
		_emit_completed()
		_is_transitioning = false
		if DisplayServer.get_name() == "headless":
			get_tree().quit()
		return

	# 1. Ball dừng, flash nhấp nháy (dùng tween nhấp nháy alpha)
	var trans_cfg: Dictionary = _auto_test_cfg.get("transition", {})
	var flash_dur: float = trans_cfg.get("flash_duration", 0.08)
	var flash_count: int = trans_cfg.get("flash_count", 4)
	
	var flash_tween: Tween = create_tween()
	for _i: int in flash_count:
		flash_tween.tween_property(ball, "modulate:a", 0.2, flash_dur)
		flash_tween.tween_property(ball, "modulate:a", 1.0, flash_dur)
	
	flash_tween.tween_callback(func():
		_current_test_index += 1

		# 2. Reset tất cả tam giác — chỉ regrow những cái đã bị phá
		var regrow_ids: Array[int] = _destroyed_ids.duplicate()
		_destroyed_ids.clear()
		map_controller.restore_all()
		if not regrow_ids.is_empty():
			render_controller.play_regrow_animation(regrow_ids)
		else:
			render_controller.play_spawn_animation()
		map_controller._build_spatial_grid()

		_destroyed_count = 0
		_glow_time = 0.0
		_test_timer = 0.0
		_bounce_count = 0
		_min_dist_to_center = INF
		_no_progress_timer = 0.0
		
		_event_bus.hud_update_requested.emit("destroyed", 0)

		if _current_test_index >= _test_radii.size():
			print("[AUTO-TEST] ══════════════════════════════════════")
			print("[AUTO-TEST] Hoàn thành tất cả %d ngưỡng!" % _test_radii.size())
			print("[AUTO-TEST] Radii tested: %s" % str(_test_radii))
			print("[AUTO-TEST] ══════════════════════════════════════")
			_auto_test_enabled = false
			_emit_completed()
			_is_transitioning = false
			if DisplayServer.get_name() == "headless":
				get_tree().quit()
			return

		# 3. Ball mới xuất hiện ở miệng (nhỏ hơn lần trước)
		var new_radius: float = _test_radii[_current_test_index]
		var new_speed: float = _test_speeds[_current_test_index]
		ball.call("reset")
		ball.set("radius", new_radius)
		ball.set("ball_speed", new_speed)
		ball.set("shrink_enabled", false)
		_place_ball_at_spawn()

		_event_bus.ball_radius_changed.emit(new_radius)

		# 4. Delay Ns -> bắt đầu lần mới
		var delay_sec: float = _auto_test_cfg.get("transition", {}).get("post_delay", 0.5)
		var delay_tween: Tween = create_tween()
		delay_tween.tween_interval(delay_sec)
		delay_tween.tween_callback(func():
			_is_running = true
			_is_transitioning = false
			ball.set("active", true)
			print("[AUTO-TEST] ── Chuyển sang test #%d — Ball radius: %.1f px, speed: %.1f px/s ──" % [_current_test_index + 1, new_radius, new_speed])
		)
	)

# ── Emoji mặt cười ở cuối spiral ──────────────────────────────────────────────

var _emoji_label: Label = null

func _create_end_emoji() -> void:
	if is_instance_valid(_emoji_label):
		_emoji_label.queue_free()
	
	var emoji_char: String = _win_effect_cfg.get("emoji", "\uD83D\uDE0A")
	var font_size: int = _win_effect_cfg.get("font_size", 80)
	var emoji_size: Array = _win_effect_cfg.get("emoji_size", [160, 160])
	
	_emoji_label = Label.new()
	_emoji_label.text = emoji_char
	_emoji_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_emoji_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	var settings: LabelSettings = LabelSettings.new()
	settings.font = load("res://font/Anton-Regular.ttf")
	settings.font_size = font_size
	_emoji_label.label_settings = settings

	var end_pos: Vector2 = map_controller.SPIRAL_CENTER
	_emoji_label.custom_minimum_size = Vector2(emoji_size[0], emoji_size[1])
	_emoji_label.position = end_pos - Vector2(emoji_size[0] * 0.5, emoji_size[1] * 0.5)
	_emoji_label.z_index = 1
	_emoji_label.z_as_relative = false
	
	add_child(_emoji_label)
