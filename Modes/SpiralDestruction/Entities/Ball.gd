## Ball.gd
## Custom physics cho quả bóng — KHÔNG dùng RigidBody2D hay CharacterBody2D.
## Xử lý: movement, CCD, spiral wall collision, triangle collision, shrink.
extends Node2D

# ── Config (set từ SpiralMode) ────────────────────────────────────────────────
var _ball_cfg: Dictionary = {}
var _spiral_cfg: Dictionary = {}

func set_ball_config(ball_cfg: Dictionary, spiral_cfg: Dictionary) -> void:
	_ball_cfg = ball_cfg
	_spiral_cfg = spiral_cfg
	# Cập nhật visual + trail sau khi config được set (vì _ready() chạy trước)
	if visual != null:
		visual.modulate = BALL_COLOR
	if trail != null:
		_update_trail_color()

# ── Config-driven getters (fallback về hardcode) ──────────────────────────────
var BALL_SPEED: float: get = _get_ball_speed
func _get_ball_speed() -> float: return _ball_cfg.get("base_speed", 600.0)

var INITIAL_RADIUS: float: get = _get_initial_radius
func _get_initial_radius() -> float: return _ball_cfg.get("initial_radius", 62.0)

var MIN_RADIUS: float: get = _get_min_radius
func _get_min_radius() -> float: return _ball_cfg.get("min_radius", 5.0)

var SHRINK_PER_BOUNCE: float: get = _get_shrink
func _get_shrink() -> float: return _ball_cfg.get("shrink_per_bounce", 1.5)

var WIN_DISTANCE: float: get = _get_win_dist
func _get_win_dist() -> float: return _ball_cfg.get("win_distance", 30.0)

var SPIRAL_CENTER: Vector2: get = _get_center
func _get_center() -> Vector2:
	var arr: Array = _spiral_cfg.get("center", [540.0, 960.0])
	return Vector2(arr[0], arr[1])

var TRAIL_LENGTH: int: get = _get_trail_len
func _get_trail_len() -> int: return _ball_cfg.get("trail_length", 20)

var BALL_COLOR: Color: get = _get_ball_color
func _get_ball_color() -> Color:
	var arr: Array = _ball_cfg.get("color", [1.0, 1.0, 1.0])
	if arr.size() >= 3:
		# Hỗ trợ cả 0-255 và 0.0-1.0
		if arr[0] > 1.0 or arr[1] > 1.0 or arr[2] > 1.0:
			return Color(arr[0]/255.0, arr[1]/255.0, arr[2]/255.0)
		return Color(arr[0], arr[1], arr[2])
	return Color.WHITE

# ── State ─────────────────────────────────────────────────────────────────────
var velocity: Vector2 = Vector2.ZERO     # Vector vận tốc hiện tại
var radius: float = INITIAL_RADIUS:      # Bán kính hiện tại
	set(value):
		radius = value
		if visual != null:
			var scale_factor: float = radius / INITIAL_RADIUS
			visual.scale = Vector2(scale_factor, scale_factor)
		if trail != null:
			trail.width = radius * 2.0

var active: bool = false                 # Chỉ xử lý physics khi active = true
var shrink_enabled: bool = true          # Cho phép co nhỏ (sẽ tắt khi chạy auto-test)
var ball_speed: float = BALL_SPEED       # Tốc độ di chuyển hiện tại

# ── Node references ───────────────────────────────────────────────────────────
@onready var visual: MeshInstance2D = $BallVisual
@onready var trail: Line2D = $Trail

## Reference đến SpiralMapController — gán từ SpiralMode sau khi setup
var map_controller: Node = null

# ── Autoload shortcuts ────────────────────────────────────────────────────────
@onready var _event_bus: Node = get_node("/root/EventBus")

# ── Trail buffer (pre-allocated, zero GC) ─────────────────────────────────────
var _trail_buffer: PackedVector2Array = PackedVector2Array()
var _trail_index: int = 0

# ── Internal ──────────────────────────────────────────────────────────────────
var _win_triggered: bool = false
var _current_active_speed: float = BALL_SPEED
var _is_wedged: bool = false

# ── Trail buffer (pre-allocated, zero GC) ─────────────────────────────────────
## _trail_ordered reuse array để tránh allocation mỗi frame
var _trail_ordered: PackedVector2Array = PackedVector2Array()

# ── Lifecycle ─────────────────────────────────────────────────────────────────
func _ready() -> void:
	# Pre-allocate trail buffer
	_trail_buffer.resize(TRAIL_LENGTH)
	for i: int in TRAIL_LENGTH:
		_trail_buffer[i] = global_position
	_trail_ordered.resize(TRAIL_LENGTH)

	# Setup visual mesh (hình tròn xấp xỉ bằng polygon)
	_setup_visual()

	# Setup trail gradient
	_setup_trail()

	# Hướng ban đầu: vào trong spiral (sẽ được set lại bởi SpiralMode._place_ball_at_spawn)
	velocity = Vector2(-0.7, 0.7).normalized() * ball_speed

	# Đảm bảo ball vẽ đè lên emoji
	z_index = 2
	z_as_relative = false

func _physics_process(delta: float) -> void:
	if not active or _win_triggered:
		return

	# Kiểm tra win NGAY CẢ KHI wedged — nếu ball ở gần tâm thì vẫn win
	_check_win_condition()

	if _is_wedged:
		return

	# Cập nhật tốc độ gia tốc dựa trên vị trí trong spiral (càng vào trong càng nhanh)
	var wall_info: Dictionary = map_controller.get_spiral_wall_info(global_position)
	var segment_idx: int = wall_info["segment_index"]
	var total_points: int = map_controller.SPIRAL_TURNS * map_controller.SPIRAL_POINTS_PER_TURN
	var progress: float = clamp(float(segment_idx) / float(total_points - 1), 0.0, 1.0)
	
	# Gia tốc tuyến tính: tăng dần từ 1.0x ở đầu xoắn đến 2.2x ở cuối xoắn
	_current_active_speed = ball_speed * (1.0 + 1.2 * progress)
	if velocity.length_squared() > 0.0001:
		velocity = velocity.normalized() * _current_active_speed

	# Win condition: ball chạm emoji ở tâm spiral
	_check_win_condition()
	if _win_triggered:
		return

	# CCD: chia frame thành nhiều bước nhỏ
	_move_with_ccd(delta)

	# Cập nhật trail
	_update_trail()

## Kiểm tra điều kiện win: ball ở gần SPIRAL_CENTER và đủ sâu trong spiral
func _check_win_condition() -> void:
	if _win_triggered:
		return
	
	# Lấy segment index để kiểm tra độ sâu
	var wall_info: Dictionary = map_controller.get_spiral_wall_info(global_position)
	var segment_idx: int = wall_info["segment_index"]
	
	# Ball chạm emoji ở tâm spiral
	if global_position.distance_to(SPIRAL_CENTER) < WIN_DISTANCE + radius:
		# Chỉ win khi ball đã ở những segment cuối của spiral (tránh premature win)
		if segment_idx >= map_controller.spiral_points.size() - 60:
			_trigger_win()

# ── Public API ────────────────────────────────────────────────────────────────

## Reset về trạng thái ban đầu (gọi từ SpiralMode.reset())
## Lưu ý: radius được set riêng bởi SpiralMode khi auto-test
func reset() -> void:
	radius = INITIAL_RADIUS
	ball_speed = BALL_SPEED
	_current_active_speed = BALL_SPEED
	velocity = Vector2(-0.7, 0.7).normalized() * ball_speed
	_win_triggered = false
	_is_wedged = false
	active = false

	# Reset trail
	for i: int in TRAIL_LENGTH:
		_trail_buffer[i] = global_position
	trail.clear_points()

	# Reset visual
	visual.scale = Vector2.ONE
	_event_bus.ball_radius_changed.emit(radius)

## Reset lại hoàn toàn trail tại vị trí hiện tại
func reset_trail() -> void:
	for i: int in TRAIL_LENGTH:
		_trail_buffer[i] = global_position
	trail.clear_points()

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
		# print("[CCD] Step: old=%s, new=%s, vel=%s" % [str(old_pos), str(global_position), str(velocity)])

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
			# Kiểm tra xem có tường chắn giữa Ball và tâm Tam giác hay không
			# để tránh việc bóng ăn gạch xuyên qua tường ở vòng bên cạnh
			var wall_blocked: Dictionary = _find_wall_intersection(global_position, tri["pos"])
			if wall_blocked["intersects"]:
				continue

			# Va chạm! Phát signal để SpiralMode xử lý
			_event_bus.brick_destroyed.emit(idx, tri["pos"], tri["color"])
			hit = true

	return hit

## Kiểm tra va chạm với tường spiral và xử lý phản xạ/trượt.
func _check_spiral_wall_collision(old_pos: Vector2) -> void:
	if map_controller == null:
		return

	# 1. Kiểm tra xem đường đi từ old_pos đến global_position có đâm xuyên qua tường không (crossover detection)
	var path_intersection: Dictionary = _find_wall_intersection(old_pos, global_position)
	if path_intersection["intersects"]:
		var normal: Vector2 = path_intersection["normal"]
		var hit_point: Vector2 = path_intersection["point"]
		var segment_idx: int = path_intersection["segment_index"]
		# print("[COLLISION] Path crossover! seg=%d, hit=%s, normal=%s" % [segment_idx, str(hit_point), str(normal)])

		# Check if wedged in tapering channel
		var local_gap: float = map_controller.get_local_gap(segment_idx)
		if radius * 2.0 >= local_gap:
			print("[COLLISION] Ball wedged (crossover)! seg=%d, gap=%.1f, diameter=%.1f" % [segment_idx, local_gap, radius * 2.0])
			velocity = Vector2.ZERO
			_is_wedged = true
			_event_bus.ball_bounced.emit(hit_point, normal)
			return

		# Đẩy bóng về phía bên kia của tường một khoảng nhỏ 1.5px để tránh việc tâm bị xuyên qua
		global_position = hit_point + normal * 1.5
		# print("[COLLISION] Pushed to %s" % str(global_position))

		# Trượt (slide) velocity
		var dot_prod: float = velocity.dot(normal)
		velocity = velocity.slide(normal).normalized() * _current_active_speed

		if dot_prod < -10.0:
			if shrink_enabled:
				_shrink_radius()
			_event_bus.ball_bounced.emit(hit_point, normal)
		return

	# 2. Nếu không đâm xuyên trực tiếp, kiểm tra va chạm dựa trên bán kính (overlap detection)
	var wall_info: Dictionary = map_controller.get_spiral_wall_info(global_position, old_pos)
	var dist_to_wall: float = wall_info["distance"]
	var segment_idx: int = wall_info["segment_index"]

	# Va chạm khi bóng chạm hoặc vượt qua tường
	if dist_to_wall <= radius:
		var normal: Vector2 = wall_info["normal"]
		var hit_point: Vector2 = wall_info["hit_point"]
		# print("[COLLISION] Overlap! seg=%d, dist=%.2f, hit=%s, normal=%s" % [segment_idx, dist_to_wall, str(hit_point), str(normal)])

		# Check if wedged in tapering channel
		var local_gap: float = map_controller.get_local_gap(segment_idx)
		if radius * 2.0 >= local_gap:
			print("[COLLISION] Ball wedged (overlap)! seg=%d, gap=%.1f, diameter=%.1f" % [segment_idx, local_gap, radius * 2.0])
			velocity = Vector2.ZERO
			_is_wedged = true
			_event_bus.ball_bounced.emit(hit_point, normal)
			return

		# Đẩy bóng ra khỏi tường
		var target_pos: Vector2 = hit_point + normal * (radius + 0.5)

		# Nếu việc đẩy ra vượt quá và đâm xuyên sang tường đối diện (ở các vòng hẹp)
		var push_intersection: Dictionary = _find_wall_intersection(old_pos, target_pos)
		if push_intersection["intersects"]:
			# print("[COLLISION] Push crossed opposite wall! seg=%d" % push_intersection["segment_index"])
			# Đẩy sát vào tường đối diện
			global_position = push_intersection["point"] + push_intersection["normal"] * 1.5
		else:
			global_position = target_pos
		# print("[COLLISION] Pushed to %s" % str(global_position))

		# Trượt (slide) velocity
		var dot_prod: float = velocity.dot(normal)
		velocity = velocity.slide(normal).normalized() * _current_active_speed

		if dot_prod < -10.0:
			if shrink_enabled:
				_shrink_radius()
			_event_bus.ball_bounced.emit(hit_point, normal)

## Tìm điểm giao nhau giữa đoạn thẳng [p1, p2] và các phân đoạn tường spiral.
## Sử dụng wall spatial grid để chỉ kiểm tra segment lân cận — O(1) thay vì O(n).
## Trả về Dictionary chứa thông tin giao điểm và normal.
func _find_wall_intersection(p1: Vector2, p2: Vector2) -> Dictionary:
	var best_t: float = 2.0
	var best_intersection: Vector2 = Vector2.ZERO
	var best_normal: Vector2 = Vector2.ZERO
	var best_seg_idx: int = -1

	# Hộp giới hạn (AABB) của đoạn [p1, p2] để lọc nhanh
	var p_min_x: float = min(p1.x, p2.x)
	var p_max_x: float = max(p1.x, p2.x)
	var p_min_y: float = min(p1.y, p2.y)
	var p_max_y: float = max(p1.y, p2.y)

	# Chỉ kiểm tra các segment gần — dùng wall grid để giảm từ O(n) xuống O(1)
	var nearby: Array[int] = map_controller.get_nearby_wall_segments((p1 + p2) * 0.5)
	var point_count: int = map_controller.spiral_points.size()

	for i: int in nearby:
		if i < 0 or i >= point_count - 1:
			continue
		if map_controller.is_gap_segment(i):
			continue

		var seg_a: Vector2 = map_controller.spiral_points[i]
		var seg_b: Vector2 = map_controller.spiral_points[i + 1]

		# AABB check cho từng phân đoạn
		var s_min_x: float = min(seg_a.x, seg_b.x)
		var s_max_x: float = max(seg_a.x, seg_b.x)
		var s_min_y: float = min(seg_a.y, seg_b.y)
		var s_max_y: float = max(seg_a.y, seg_b.y)

		if p_max_x < s_min_x or p_min_x > s_max_x or p_max_y < s_min_y or p_min_y > s_max_y:
			continue

		# Thuật toán tìm giao điểm 2 đoạn thẳng (line segment intersection)
		var denom: float = (seg_b.y - seg_a.y) * (p2.x - p1.x) - (seg_b.x - seg_a.x) * (p2.y - p1.y)
		if abs(denom) < 0.0001:
			continue

		var ua: float = ((seg_b.x - seg_a.x) * (p1.y - seg_a.y) - (seg_b.y - seg_a.y) * (p1.x - seg_a.x)) / denom
		var ub: float = ((p2.x - p1.x) * (p1.y - seg_a.y) - (p2.y - p1.y) * (p1.x - seg_a.x)) / denom

		# Giao điểm hợp lệ nếu ua và ub đều nằm trong khoảng [0, 1]
		if ua >= 0.0 and ua <= 1.0 and ub >= 0.0 and ub <= 1.0:
			if ua < best_t:
				best_t = ua
				best_intersection = p1 + ua * (p2 - p1)
				var seg_dir: Vector2 = (seg_b - seg_a).normalized()
				var normal: Vector2 = Vector2(-seg_dir.y, seg_dir.x)
				# Định hướng normal hướng về phía p1 (phía xuất phát của bóng)
				var to_p1: Vector2 = p1 - best_intersection
				if normal.dot(to_p1) < 0.0:
					normal = -normal
				best_normal = normal
				best_seg_idx = i

	if best_seg_idx != -1:
		return {
			"intersects": true,
			"point": best_intersection,
			"normal": best_normal,
			"segment_index": best_seg_idx
		}
	return {"intersects": false}

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

func _update_trail_color() -> void:
	var ball_color: Color = BALL_COLOR
	var gradient: Gradient = Gradient.new()
	gradient.add_point(0.0, Color(ball_color.r, ball_color.g, ball_color.b, 0.0))
	gradient.add_point(1.0, Color(ball_color.r, ball_color.g, ball_color.b, 0.8))
	trail.gradient = gradient

func _update_trail() -> void:
	_trail_buffer[_trail_index] = global_position
	_trail_index = (_trail_index + 1) % TRAIL_LENGTH

	# Reuse pre-allocated array — zero GC
	for i: int in TRAIL_LENGTH:
		var idx: int = (_trail_index + i) % TRAIL_LENGTH
		_trail_ordered[i] = _trail_buffer[idx]

	trail.points = _trail_ordered

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
	# Màu từ config
	visual.modulate = BALL_COLOR

func _setup_trail() -> void:
	trail.top_level = true
	trail.z_index = 2
	trail.z_as_relative = false
	trail.width = radius * 2.0
	trail.antialiased = true
	trail.joint_mode = Line2D.LINE_JOINT_ROUND
	trail.begin_cap_mode = Line2D.LINE_CAP_ROUND
	trail.end_cap_mode = Line2D.LINE_CAP_ROUND
	
	# Tạo width curve hình tam giác nhỏ dần (đuôi = 0, đầu = 1.0)
	var curve: Curve = Curve.new()
	curve.add_point(Vector2(0.0, 0.0))
	curve.add_point(Vector2(1.0, 1.0))
	trail.width_curve = curve

	_update_trail_color()

