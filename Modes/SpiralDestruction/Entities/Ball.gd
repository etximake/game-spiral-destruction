## Ball.gd
## Custom physics cho quả bóng — KHÔNG dùng RigidBody2D hay CharacterBody2D.
## Xử lý: movement, CCD, spiral wall collision, triangle collision, shrink.
extends Node2D

# ── Hằng số ───────────────────────────────────────────────────────────────────
const BALL_SPEED: float = 420.0          # px/s — không đổi trong toàn bộ simulation
const INITIAL_RADIUS: float = 54.0       # px
const MIN_RADIUS: float = 5.0            # px — không co nhỏ hơn
const SHRINK_PER_BOUNCE: float = 1.5     # px — giảm mỗi lần chạm tường spiral
const WIN_DISTANCE: float = 30.0         # px — khoảng cách đến tâm để win
const SPIRAL_CENTER: Vector2 = Vector2(540.0, 960.0)

# ── State ─────────────────────────────────────────────────────────────────────
var velocity: Vector2 = Vector2.ZERO     # Vector vận tốc hiện tại
var radius: float = INITIAL_RADIUS       # Bán kính hiện tại
var active: bool = false                 # Chỉ xử lý physics khi active = true

# ── Node references ───────────────────────────────────────────────────────────
@onready var visual: MeshInstance2D = $BallVisual
@onready var trail: Line2D = $Trail

## Reference đến SpiralMapController — gán từ SpiralMode sau khi setup
var map_controller: Node = null

# ── Autoload shortcuts ────────────────────────────────────────────────────────
@onready var _event_bus: Node = get_node("/root/EventBus")

# ── Trail buffer (pre-allocated, zero GC) ─────────────────────────────────────
const TRAIL_LENGTH: int = 20
var _trail_buffer: PackedVector2Array = PackedVector2Array()
var _trail_index: int = 0

# ── Internal ──────────────────────────────────────────────────────────────────
var _win_triggered: bool = false

# ── Lifecycle ─────────────────────────────────────────────────────────────────
func _ready() -> void:
	# Pre-allocate trail buffer
	_trail_buffer.resize(TRAIL_LENGTH)
	for i: int in TRAIL_LENGTH:
		_trail_buffer[i] = global_position

	# Setup visual mesh (hình tròn xấp xỉ bằng polygon)
	_setup_visual()

	# Setup trail gradient
	_setup_trail()

	# Hướng ban đầu: vào trong spiral
	velocity = Vector2(0.6, 0.8).normalized() * BALL_SPEED

func _physics_process(delta: float) -> void:
	if not active or _win_triggered:
		return

	# Kiểm tra win condition trước
	if global_position.distance_to(SPIRAL_CENTER) < WIN_DISTANCE:
		_trigger_win()
		return

	# CCD: chia frame thành nhiều bước nhỏ
	_move_with_ccd(delta)

	# Cập nhật trail
	_update_trail()

	# Cập nhật visual scale theo radius
	var scale_factor: float = radius / INITIAL_RADIUS
	visual.scale = Vector2(scale_factor, scale_factor)

# ── Public API ────────────────────────────────────────────────────────────────

## Reset về trạng thái ban đầu (gọi từ SpiralMode.reset())
func reset() -> void:
	radius = INITIAL_RADIUS
	velocity = Vector2(0.6, 0.8).normalized() * BALL_SPEED
	_win_triggered = false
	active = false

	# Reset trail
	for i: int in TRAIL_LENGTH:
		_trail_buffer[i] = global_position
	trail.clear_points()

	# Reset visual
	visual.scale = Vector2.ONE
	_event_bus.ball_radius_changed.emit(radius)

# ── CCD Movement ──────────────────────────────────────────────────────────────

func _move_with_ccd(delta: float) -> void:
	# Tính số bước cần thiết để không xuyên vật thể
	# Mỗi bước tối đa = radius / 2 để đảm bảo không bỏ sót collision
	var step_size: float = radius * 0.5
	var total_distance: float = velocity.length() * delta
	var steps: int = max(1, int(ceil(total_distance / step_size)))
	var step_delta: float = delta / float(steps)

	for _i: int in steps:
		var old_pos: Vector2 = global_position
		global_position += velocity * step_delta

		# 1. Kiểm tra va chạm với tam giác
		var hit_triangle: bool = _check_triangle_collisions()

		# 2. Kiểm tra va chạm với tường spiral
		if not hit_triangle:
			_check_spiral_wall_collision(old_pos)

## Kiểm tra va chạm với các tam giác gần nhất qua spatial grid.
## Trả về true nếu có va chạm.
func _check_triangle_collisions() -> bool:
	if map_controller == null:
		return false

	var nearby: Array = map_controller.get_nearby_triangles(global_position)
	var hit: bool = false

	for idx: int in nearby:
		var tri: Dictionary = map_controller.triangles[idx]
		if not tri["alive"]:
			continue

		var dist: float = global_position.distance_to(tri["pos"])
		var combined_radius: float = radius + tri["collision_radius"]

		if dist < combined_radius:
			# Va chạm! Phát signal để SpiralMode xử lý
			_event_bus.brick_destroyed.emit(idx, tri["pos"], tri["color"])
			hit = true

	return hit

## Kiểm tra va chạm với tường spiral và xử lý phản xạ.
func _check_spiral_wall_collision(_old_pos: Vector2) -> void:
	if map_controller == null:
		return

	var wall_info: Dictionary = map_controller.get_spiral_wall_info(global_position)
	var dist_to_wall: float = wall_info["distance"]
	var segment_idx: int = wall_info["segment_index"]

	# Bỏ qua khe hở (endpoint spiral)
	if map_controller.is_gap_segment(segment_idx):
		return

	# Va chạm khi bóng chạm hoặc vượt qua tường
	if dist_to_wall <= radius:
		var normal: Vector2 = wall_info["normal"]
		var hit_point: Vector2 = wall_info["hit_point"]

		# Đẩy bóng ra khỏi tường
		global_position = hit_point + normal * (radius + 0.5)

		# Phản xạ velocity — G1 gotcha: normalize + nhân lại speed cố định
		velocity = velocity.bounce(normal).normalized() * BALL_SPEED

		# Co nhỏ bóng
		_shrink_radius()

		# Phát signal
		_event_bus.ball_bounced.emit(hit_point, normal)

## Co nhỏ bán kính bóng sau mỗi lần chạm tường.
func _shrink_radius() -> void:
	radius = max(MIN_RADIUS, radius - SHRINK_PER_BOUNCE)
	_event_bus.ball_radius_changed.emit(radius)

# ── Win ───────────────────────────────────────────────────────────────────────

func _trigger_win() -> void:
	_win_triggered = true
	active = false
	get_parent().on_completed()

# ── Trail ─────────────────────────────────────────────────────────────────────

func _update_trail() -> void:
	_trail_buffer[_trail_index] = global_position
	_trail_index = (_trail_index + 1) % TRAIL_LENGTH

	var ordered: PackedVector2Array = PackedVector2Array()
	ordered.resize(TRAIL_LENGTH)
	for i: int in TRAIL_LENGTH:
		var idx: int = (_trail_index + i) % TRAIL_LENGTH
		ordered[i] = _trail_buffer[idx]

	trail.points = ordered

# ── Visual setup ──────────────────────────────────────────────────────────────

func _setup_visual() -> void:
	var mesh: ArrayMesh = ArrayMesh.new()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)

	var segments: int = 16
	var verts: PackedVector2Array = PackedVector2Array()
	var indices: PackedInt32Array = PackedInt32Array()

	verts.append(Vector2.ZERO)
	for i: int in segments:
		var angle: float = (float(i) / float(segments)) * TAU
		verts.append(Vector2(cos(angle), sin(angle)) * INITIAL_RADIUS)

	for i: int in segments:
		indices.append(0)
		indices.append(i + 1)
		indices.append((i + 1) % segments + 1)

	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	visual.mesh = mesh
	# Màu trắng qua modulate — không cần material riêng
	visual.modulate = Color.WHITE

func _setup_trail() -> void:
	trail.width = radius * 0.5
	var gradient: Gradient = Gradient.new()
	gradient.add_point(0.0, Color(1, 1, 1, 0.0))
	gradient.add_point(1.0, Color(1, 1, 1, 0.8))
	trail.gradient = gradient
