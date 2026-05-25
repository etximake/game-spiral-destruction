## SpiralMapController.gd
## Spiral xoắn từ NGOÀI VÀO TRONG (giống vỏ ốc 2D):
##   - θ=0 = vòng ngoài cùng (miệng ở 3h, bán kính lớn nhất)
##   - θ tăng = đi vào tâm (bán kính giảm dần)
##   - Khoảng cách vòng thu hẹp dần: max (ngoài) → min (trong)
##   - Cuối spiral = tâm (emoji mặt cười)
extends Node

# ── Config (set từ SpiralMode.set_config) ─────────────────────────────────────
var _spiral_cfg: Dictionary = {}
var _tri_cfg: Dictionary = {}
var _grid_cfg: Dictionary = {}

func set_config(config: Dictionary) -> void:
	_spiral_cfg = config.get("spiral", {})
	_tri_cfg = config.get("triangles", {})
	_grid_cfg = config.get("spatial_grid", {})

# ── Hằng số Spiral (từ config nếu có, fallback về hardcode) ──────────────────
var SPIRAL_GAP_MAX: float:
	get: return _spiral_cfg.get("gap_max", 110.0)
var SPIRAL_GAP_MIN: float:
	get: return _spiral_cfg.get("gap_min", 35.0)
var SPIRAL_TURNS: float:
	get: return _spiral_cfg.get("turns", 7.0)
var SPIRAL_POINTS_PER_TURN: int:
	get: return _spiral_cfg.get("points_per_turn", 120)
var SPIRAL_CENTER: Vector2:
	get:
		var arr: Array = _spiral_cfg.get("center", [540.0, 960.0])
		return Vector2(arr[0], arr[1])

# ── Hằng số Tam giác (từ config nếu có) ───────────────────────────────────────
var TRIANGLE_ANGLE_STEP: float:
	get: return deg_to_rad(_tri_cfg.get("angle_step_deg", 11.25))
var TRIANGLE_SIDE: float:
	get: return _tri_cfg.get("side", 24.0)
var TRIANGLE_GAP: float:
	get: return _tri_cfg.get("gap_from_wall", 4.0)
var TRIANGLE_COLLISION_RATIO: float:
	get: return _tri_cfg.get("collision_ratio", 0.45)
var TRI_SIZE_RATIO: float:
	get: return _tri_cfg.get("size_ratio", 0.95)
var TRI_MIN_SIZE: float:
	get: return _tri_cfg.get("min_size", 24.0)
var TRI_MAX_SIZE: float:
	get: return _tri_cfg.get("max_size", 150.0)
var TRI_SPACING_RATIO: float:
	get: return _tri_cfg.get("spacing_ratio", 1.15)
var TRI_COLOR_HUE_START: float:
	get: return _tri_cfg.get("color_hue_start", 0.0)
var TRI_COLOR_HUE_RANGE: float:
	get: return _tri_cfg.get("color_hue_range", 1.3)
var TRI_SKIP_AT_SPAWN: int:
	get: return _tri_cfg.get("skip_at_spawn", 3)
var TRI_SKIP_AT_END: int:
	get: return _tri_cfg.get("skip_at_end", 2)
var TRI_STOP_DIST: float:
	get: return _tri_cfg.get("stop_distance_from_center", 80.0)

# ── Hằng số Spatial Grid (từ config nếu có) ───────────────────────────────────
var GRID_CELL_SIZE: float:
	get: return _grid_cfg.get("cell_size", 100.0)

# ── Dữ liệu xuất ra ──────────────────────────────────────────────────────────
var spiral_points: PackedVector2Array = PackedVector2Array()
var triangles: Array[Dictionary] = []
var total_triangles: int = 0
var spatial_grid: Dictionary = {}

# ── Wall Spatial Grid ─────────────────────────────────────────────────────────
## Grid phân đoạn wall — giảm từ O(n) xuống O(1) cho wall collision
var wall_grid: Dictionary = {}
var wall_segment_count: int = 0

## Vị trí cuối spiral (tâm) — nơi đặt emoji, WIN khi ball chạm đây
var spiral_end_position: Vector2 = Vector2.ZERO
## Bán kính ngoài cùng (miệng spiral)
var outer_radius: float = 0.0

# ── Public API ────────────────────────────────────────────────────────────────

func generate() -> void:
	spiral_points = _generate_spiral_points()
	triangles = _generate_triangles()
	total_triangles = triangles.size()
	_build_spatial_grid()
	_build_wall_grid()
	# Cuối spiral = điểm cuối cùng (gần tâm nhất)
	spiral_end_position = spiral_points[spiral_points.size() - 1]
	# Bán kính ngoài = điểm đầu tiên
	outer_radius = spiral_points[0].distance_to(SPIRAL_CENTER)

func get_nearby_triangles(world_pos: Vector2) -> Array[int]:
	var result: Array[int] = []
	var cell: Vector2i = _world_to_cell(world_pos)
	for dx: int in [-1, 0, 1]:
		for dy: int in [-1, 0, 1]:
			var key: Vector2i = Vector2i(cell.x + dx, cell.y + dy)
			if spatial_grid.has(key):
				for idx: int in spatial_grid[key]:
					if triangles[idx]["alive"]:
						result.append(idx)
	return result

## Lấy danh sách các phân đoạn tường gần vị trí world_pos.
## Sử dụng spatial grid để giảm từ O(n) xuống O(1).
func get_nearby_wall_segments(world_pos: Vector2) -> Array[int]:
	var result: Array[int] = []
	var cell: Vector2i = _world_to_cell(world_pos)
	for dx: int in [-1, 0, 1]:
		for dy: int in [-1, 0, 1]:
			var key: Vector2i = Vector2i(cell.x + dx, cell.y + dy)
			if wall_grid.has(key):
				for idx: int in wall_grid[key]:
					result.append(idx)
	return result

func destroy_triangle(triangle_id: int) -> void:
	if triangle_id < 0 or triangle_id >= total_triangles:
		return
	triangles[triangle_id]["alive"] = false
	_remove_from_grid(triangle_id)

func restore_all() -> void:
	for i: int in total_triangles:
		triangles[i]["alive"] = true
	_build_spatial_grid()
	_build_wall_grid()

## Tìm segment tường gần nhất với world_pos.
## Dùng wall_grid để chỉ kiểm tra các segment lân cận.
func get_spiral_wall_info(world_pos: Vector2, old_pos: Vector2 = Vector2.ZERO) -> Dictionary:
	var best_dist: float = INF
	var best_normal: Vector2 = Vector2.UP
	var best_hit: Vector2 = world_pos
	var best_seg: int = -1

	var nearby: Array[int] = get_nearby_wall_segments(world_pos)
	if nearby.is_empty():
		# Fallback: nếu không có segment nào trong grid (rare), dùng toàn bộ
		nearby = _get_all_wall_segments()

	var point_count: int = spiral_points.size()
	for seg_idx: int in nearby:
		if seg_idx < 0 or seg_idx >= point_count - 1:
			continue
		var seg_a: Vector2 = spiral_points[seg_idx]
		var seg_b: Vector2 = spiral_points[seg_idx + 1]
		var closest: Vector2 = _closest_point_on_segment(world_pos, seg_a, seg_b)
		var dist: float = world_pos.distance_to(closest)

		if dist < best_dist:
			best_dist = dist
			best_hit = closest
			best_seg = seg_idx
			var seg_dir: Vector2 = (seg_b - seg_a).normalized()
			var normal: Vector2 = Vector2(-seg_dir.y, seg_dir.x)
			
			# Orient normal towards old_pos (if provided) to prevent tunneling,
			# otherwise default to pointing towards the ball.
			if old_pos != Vector2.ZERO:
				var closest_old: Vector2 = _closest_point_on_segment(old_pos, seg_a, seg_b)
				var to_old: Vector2 = old_pos - closest_old
				if to_old.length_squared() > 0.0001:
					if normal.dot(to_old) < 0.0:
						normal = -normal
				else:
					if normal.dot(world_pos - closest) < 0.0:
						normal = -normal
			else:
				if normal.dot(world_pos - closest) < 0.0:
					normal = -normal
					
			best_normal = normal

	return {
		"normal": best_normal,
		"hit_point": best_hit,
		"distance": best_dist,
		"segment_index": best_seg
	}

func is_gap_segment(segment_index: int) -> bool:
	return false

func get_local_gap(segment_index: int) -> float:
	var total_points: int = int(SPIRAL_TURNS * SPIRAL_POINTS_PER_TURN)
	var turn_progress: float = float(segment_index) / float(total_points - 1)
	return lerp(SPIRAL_GAP_MAX, SPIRAL_GAP_MIN, turn_progress)

# ── Private: Sinh spiral points ───────────────────────────────────────────────
## Spiral từ NGOÀI VÀO TRONG:
## θ=0 → bán kính lớn nhất (ngoài), θ=max → bán kính nhỏ nhất (tâm)

func _generate_spiral_points() -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	var total_points: int = int(SPIRAL_TURNS * SPIRAL_POINTS_PER_TURN)

	var theta_max: float = SPIRAL_TURNS * TAU
	# Tính bán kính ngoài cùng (tổng tích phân khoảng cách)
	var r_max: float = _total_radius()

	for i: int in total_points:
		var theta: float = (float(i) / float(total_points - 1)) * theta_max
		# Bán kính GIẢM DẦN từ ngoài vào trong
		var r: float = r_max - _accumulated_radius(theta)

		# Khi bán kính quá nhỏ (lọt vào vùng emoji), dừng lại để không đè lên emoji
		var stop_r: float = _spiral_cfg.get("stop_radius", 65.0)
		if r < stop_r:
			break

		# Miệng ở 3h: θ=0 = hướng phải
		var x: float = SPIRAL_CENTER.x + r * cos(theta)
		var y: float = SPIRAL_CENTER.y + r * sin(theta)
		points.append(Vector2(x, y))

	return points

## Tổng bán kính (từ θ=0 đến θ=max) — bán kính ngoài cùng
func _total_radius() -> float:
	return _accumulated_radius(SPIRAL_TURNS * TAU)

## Tích phân khoảng cách từ 0 đến theta
## gap(t) = lerp(max, min, t/θ_max) — thu hẹp dần
## ∫₀^θ gap(t)/(2π) dt = (1/2π) × [max×θ - (max-min)×θ²/(2×θ_max)]
func _accumulated_radius(theta: float) -> float:
	var theta_max: float = SPIRAL_TURNS * TAU
	var gap_range: float = SPIRAL_GAP_MAX - SPIRAL_GAP_MIN
	return (SPIRAL_GAP_MAX * theta - gap_range * theta * theta / (2.0 * theta_max)) / TAU

# ── Private: Sinh tam giác đều ────────────────────────────────────────────────

func _generate_triangles() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var theta_max: float = SPIRAL_TURNS * TAU
	var r_max: float = _total_radius()

	# Skip khe hở spawn (dùng config)
	var theta: float = TRIANGLE_ANGLE_STEP * float(TRI_SKIP_AT_SPAWN)
	while theta < theta_max - TRIANGLE_ANGLE_STEP * float(TRI_SKIP_AT_END):
		var r: float = r_max - _accumulated_radius(theta)

		# Điểm trên đường spiral
		var spiral_x: float = SPIRAL_CENTER.x + r * cos(theta)
		var spiral_y: float = SPIRAL_CENTER.y + r * sin(theta)
		var spiral_pos: Vector2 = Vector2(spiral_x, spiral_y)

		# Hướng vào tâm (tam giác nằm phía trong đường spiral)
		var to_center: Vector2 = (SPIRAL_CENTER - spiral_pos).normalized()

		# Kích thước tam giác tỷ lệ với khoảng cách vòng (dùng config)
		var turn_progress: float = theta / theta_max
		var local_gap: float = lerp(SPIRAL_GAP_MAX, SPIRAL_GAP_MIN, turn_progress)
		var max_possible_size: float = (local_gap - TRIANGLE_GAP) / 0.866
		var size: float = clamp(max_possible_size * TRI_SIZE_RATIO, TRI_MIN_SIZE, TRI_MAX_SIZE)

		# Vị trí tam giác: cách đường spiral về phía tâm
		var pos: Vector2 = spiral_pos + to_center * (TRIANGLE_GAP + size * 0.289)
		
		# Vị trí trên đường spiral (cạnh đáy tam giác chạm tường)
		var base_pos: Vector2 = spiral_pos + to_center * TRIANGLE_GAP

		# Không vẽ đè lên emoji (dùng config)
		if pos.distance_to(SPIRAL_CENTER) < TRI_STOP_DIST:
			theta += TRIANGLE_ANGLE_STEP
			continue

		# Góc xoay: đỉnh hướng vào tâm
		var angle: float = to_center.angle() + PI / 2.0

		# Màu gradient theo vòng (dùng config)
		var hue: float = fmod(TRI_COLOR_HUE_START + turn_progress * TRI_COLOR_HUE_RANGE, 1.0)
		var color: Color = Color.from_hsv(hue, 1.0, 1.0)

		result.append({
			"pos": pos,
			"base_pos": base_pos,
			"collision_pos": pos,  # Tâm collision tại vị trí visual (trong kênh)
			"angle": angle,
			"size": size,
			"color": color,
			"alive": true,
			"collision_radius": size * TRIANGLE_COLLISION_RATIO,
			"theta": theta,
		})

		# Tính góc bước tiếp theo dựa trên size của tam giác và spacing_ratio
		var step: float = (size * TRI_SPACING_RATIO) / r
		step = max(step, TRIANGLE_ANGLE_STEP)
		theta += step
	return result

# ── Private: Spatial Grid ─────────────────────────────────────────────────────

func _build_spatial_grid() -> void:
	spatial_grid.clear()
	for i: int in triangles.size():
		if triangles[i]["alive"]:
			_add_to_grid(i)

func _add_to_grid(triangle_id: int) -> void:
	var cell: Vector2i = _world_to_cell(triangles[triangle_id]["pos"])
	if not spatial_grid.has(cell):
		spatial_grid[cell] = []
	spatial_grid[cell].append(triangle_id)

func _remove_from_grid(triangle_id: int) -> void:
	var cell: Vector2i = _world_to_cell(triangles[triangle_id]["pos"])
	if spatial_grid.has(cell):
		spatial_grid[cell].erase(triangle_id)

func _world_to_cell(world_pos: Vector2) -> Vector2i:
	return Vector2i(
		int(floor(world_pos.x / GRID_CELL_SIZE)),
		int(floor(world_pos.y / GRID_CELL_SIZE))
	)

# ── Private: Geometry helpers ─────────────────────────────────────────────────

func _build_wall_grid() -> void:
	wall_grid.clear()
	wall_segment_count = spiral_points.size() - 1
	for i: int in wall_segment_count:
		if is_gap_segment(i):
			continue
		var a: Vector2 = spiral_points[i]
		var b: Vector2 = spiral_points[i + 1]
		var mid: Vector2 = (a + b) * 0.5
		var cell: Vector2i = _world_to_cell(mid)
		if not wall_grid.has(cell):
			wall_grid[cell] = []
		wall_grid[cell].append(i)

func _get_all_wall_segments() -> Array[int]:
	var result: Array[int] = []
	result.resize(wall_segment_count)
	for i: int in wall_segment_count:
		result[i] = i
	return result

func _closest_point_on_segment(p: Vector2, a: Vector2, b: Vector2) -> Vector2:
	var ab: Vector2 = b - a
	var ab_len_sq: float = ab.length_squared()
	if ab_len_sq < 0.0001:
		return a
	var t: float = clamp((p - a).dot(ab) / ab_len_sq, 0.0, 1.0)
	return a + ab * t

func _estimate_nearest_segment_index(world_pos: Vector2) -> int:
	var dist_from_center: float = world_pos.distance_to(SPIRAL_CENTER)
	var total_points: int = spiral_points.size()
	# Sample 20 điểm để ước tính vị trí gần nhất
	var best_idx: int = total_points / 2
	var best_diff: float = INF
	for s: int in 20:
		var idx: int = int(float(s) / 20.0 * float(total_points - 1))
		var r: float = spiral_points[idx].distance_to(SPIRAL_CENTER)
		var diff: float = abs(r - dist_from_center)
		if diff < best_diff:
			best_diff = diff
			best_idx = idx
	return best_idx
