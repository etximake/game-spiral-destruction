## SpiralMode.gd
## Scene controller cho Spiral Destruction mode.
## Implements SimulationBase interface.
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

# ── State ─────────────────────────────────────────────────────────────────────
var _destroyed_count: int = 0
var _is_running: bool = false
var _glow_time: float = 0.0  # Dùng cho pulse animation

# ── Lifecycle ─────────────────────────────────────────────────────────────────
func _process(delta: float) -> void:
	if not _is_running:
		return
	# Center glow pulse — task 6.4
	# Sin wave: energy dao động giữa 0.8 và 2.0, period 2s
	_glow_time += delta
	center_glow.energy = 1.4 + 0.6 * sin(_glow_time * PI)  # PI rad/s = period 2s

# ── SimulationBase interface ──────────────────────────────────────────────────

func setup() -> void:
	map_controller.generate()
	render_controller.setup(map_controller)
	ball.set("map_controller", map_controller)
	_place_ball_at_spawn()
	_connect_signals()

	_event_bus.hud_update_requested.emit("total", map_controller.total_triangles)
	_event_bus.hud_update_requested.emit("destroyed", 0)
	_event_bus.ball_radius_changed.emit(ball.get("radius"))

func start() -> void:
	_is_running = true
	ball.set("active", true)

func reset() -> void:
	_is_running = false
	_destroyed_count = 0
	_glow_time = 0.0

	_place_ball_at_spawn()
	ball.set("active", false)
	ball.call("reset")

	map_controller.restore_all()
	render_controller.restore_all(map_controller.triangles)
	map_controller._build_spatial_grid()

	# Restore modulate (có thể đã fade out)
	modulate = Color.WHITE

	_event_bus.hud_update_requested.emit("destroyed", 0)
	_event_bus.ball_radius_changed.emit(ball.get("radius"))

	_is_running = true
	ball.set("active", true)

func on_completed() -> void:
	_is_running = false
	ball.set("active", false)

	# Win burst — task 6.6: phun nhiều debris từ tâm
	var center: Vector2 = map_controller.SPIRAL_CENTER
	for i: int in 8:
		var offset: Vector2 = Vector2(randf_range(-30.0, 30.0), randf_range(-30.0, 30.0))
		var burst_color: Color = Color.from_hsv(float(i) / 8.0, 1.0, 1.0)
		_object_pool.get_debris(center + offset, burst_color)

	# Center glow burst
	var tween: Tween = create_tween()
	tween.tween_property(center_glow, "energy", 8.0, 0.2)
	tween.tween_interval(1.5)
	tween.tween_property(center_glow, "energy", 0.0, 1.0)

	# Fade out toàn bộ scene
	var fade_tween: Tween = create_tween()
	fade_tween.tween_interval(2.0)
	fade_tween.tween_property(self, "modulate:a", 0.0, 1.5)

	_emit_completed()

# ── Signal handlers ───────────────────────────────────────────────────────────

func _on_brick_destroyed(brick_id: int, world_position: Vector2, color: Color) -> void:
	if not _is_running:
		return
	render_controller.hide_triangle(brick_id)
	map_controller.destroy_triangle(brick_id)
	_object_pool.get_debris(world_position, color)
	_destroyed_count += 1
	_event_bus.hud_update_requested.emit("destroyed", _destroyed_count)

func _on_ball_bounced(_position: Vector2, _normal: Vector2) -> void:
	if not _is_running:
		return
	if screen_shake.has_method("shake"):
		var intensity: float = ball.get("radius") / 54.0 * 3.0
		screen_shake.call("shake", intensity)

# ── Private ───────────────────────────────────────────────────────────────────

func _place_ball_at_spawn() -> void:
	var spawn_point: Vector2 = map_controller.spiral_points[0]
	var dir_out: Vector2 = (spawn_point - map_controller.SPIRAL_CENTER).normalized()
	ball.global_position = spawn_point + dir_out * 80.0

func _connect_signals() -> void:
	if not _event_bus.brick_destroyed.is_connected(_on_brick_destroyed):
		_event_bus.brick_destroyed.connect(_on_brick_destroyed)
	if not _event_bus.ball_bounced.is_connected(_on_ball_bounced):
		_event_bus.ball_bounced.connect(_on_ball_bounced)
