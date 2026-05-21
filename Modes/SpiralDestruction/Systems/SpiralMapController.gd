## SpiralMapController.gd
## Quản lý toàn bộ dữ liệu toán học của spiral:
##   - Sinh điểm spiral (wall segments)
##   - Sinh dữ liệu tam giác (vị trí, góc, scale, màu)
##   - Spatial grid cho collision O(1)
##   - Lookup table wall segments cho ball collision
extends Node

# ── Hằng số Spiral ────────────────────────────────────────────────────────────
const SPIRAL_A: float = 30.0          # Offset từ tâm (px)
const SPIRAL_B: float = 55.0          # Khoảng cách giữa các vòng (px)
const SPIRAL_TURNS: float = 7.0       # Số vòng xoắn
const SPIRAL_POINTS_PER_TURN: int = 120  # Độ mịn của đường spiral (điểm/vòng)
const SPIRAL_CENTER: Vector2 = Vector2(540.0, 960.0)  # Tâm viewport

# ── Hằng số Tam giác ──────────────────────────────────────────────────────────
## Góc giữa 2 tam giác liên tiếp (radian) — ~18° = 1 tam giác/18°
const TRIANGLE_ANGLE_STEP: float = PI / 10.0  # 18° = π/10
## Tỉ lệ kích thước tam giác so với khoảng cách vòng
const TRIANGLE_SIZE_RATIO: float = 0.38
## Collision radius = base_width × hệ số này
const TRIANGLE_COLLISION_RATIO: float = 0.6

# ── Hằng số Spatial Grid ─────────────────────────────────────────────────────
const GRID_CELL_SIZE: float = 108.0   # = ball_radius_max × 2

# ── Dữ liệu xuất ra (đọc bởi RenderController và Ball) ───────────────────────

## Mảng điểm trên đường spiral (wall segments)
## Dùng để vẽ Line2D và tính wall collision
var spiral_points: PackedVector2Array = PackedVector2Array()

## Dữ liệu từng tam giác — struct-like Dictionary
## Mỗi phần tử: { pos, angle, size, color, alive, collision_radius }
var triangles: Array[Dictionary] = []

## Tổng số tam giác
var total_triangles: int = 0

## Spatial grid: Vector2i → Array[int] (danh sách triangle index)
var spatial_grid: Dictionary = {}

# ── Public API ────────────────────────────────────────────────────────────────

## Sinh toàn bộ dữ liệu. Gọi một lần trong setup().
func generate() -> void:
	spiral_points = _generate_spiral_points()
	triangles = _generate_triangles()
	total_triangles = triangles.size()
	_build_spatial_grid()

## Lấy danh sách triangle index trong vùng lân cận của một điểm.
## Trả về Array[int] — chỉ các tam giác còn sống trong 9 ô grid xung quanh.
func get_nearby_triangles(world_pos: Vector2) -> Array[int]:
	var result: Array[int] = []
	var cell: Vector2i = _world_to_cell(world_pos)

	# Kiểm tra 9 ô xung quanh (3×3)
	for dx: int in [-1, 0, 1]:
		for dy: int in [-1, 0, 1]:
			var key: Vector2i = Vector2i(cell.x + dx, cell.y + dy)
			if spatial_grid.has(key):
				for idx: int in spatial_grid[key]:
					if triangles[idx]["alive"]:
						result.append(idx)
	return result

## Đánh dấu tam giác đã vỡ và xóa khỏi spatial grid.
func destroy_triangle(triangle_id: int) -> void:
	if triangle_id < 0 or triangle_id >= total_triangles:
		return
	triangles[triangle_id]["alive"] = false
	_remove_from_grid(triangle_id)

## Khôi phục tất cả tam giác (dùng khi reset).
func restore_all() -> void:
	for i: int in total_triangles:
		triangles[i]["alive"] = true
	_build_spatial_grid()

## Tính normal của tường spiral tại điểm gần nhất với world_pos.
## Trả về Dictionary { "normal": Vector2, "hit_point": Vector2, "distance": float, "segment_index": int }
func get_spiral_wall_info(world_pos: Vector2) -> Dictionary:
	var best_dist: float = INF
	var best_normal: Vector2 = Vector2.UP
	var best_hit: Vector2 = world_pos
	var best_seg: int = -1

	var point_count: int = spiral_points.size()
	# Tìm segment gần nhất — chỉ kiểm tra trong vùng bán kính hợp lý
	# Tối ưu: chỉ check ~30 segment gần nhất thay vì toàn bộ
	var approx_idx: int = _estimate_nearest_segment_index(world_pos)
	var search_range: int = 40

	var start_idx: int = max(0, approx_idx - search_range)
	var end_idx: int = min(point_count - 2, approx_idx + search_range)

	for i: int in range(start_idx, end_idx):
		var seg_a: Vector2 = spiral_points[i]
		var seg_b: Vector2 = spiral_points[i + 1]

		var closest: Vector2 = _closest_point_on_segment(world_pos, seg_a, seg_b)
		var dist: float = world_pos.distance_to(closest)

		if dist < best_dist:
			best_dist = dist
			best_hit = closest
			best_seg = i

			# Normal = vector vuông góc với segment, hướng vào tâm
			var seg_dir: Vector2 = (seg_b - seg_a).normalized()
			var normal: Vector2 = Vector2(-seg_dir.y, seg_dir.x)

			# Đảm bảo normal hướng vào tâm (G5 gotcha)
			if normal.dot(SPIRAL_CENTER - closest) < 0.0:
				normal = -normal
			best_normal = normal

	return {
		"normal": best_normal,
		"hit_point": best_hit,
		"distance": best_dist,
		"segment_index": best_seg
	}

## Kiểm tra xem segment_index có phải là endpoint (khe hở) không.
## Khe hở tại index 0 và index cuối cùng — bóng đi qua, không nảy.
func is_gap_segment(segment_index: int) -> bool:
	if segment_index < 0:
		return true
	# Khe hở: 5 segment đầu tiên (điểm spawn bóng)
	if segment_index < 5:
		return true
	return false

# ── Private: Sinh spiral points ───────────────────────────────────────────────

func _generate_spiral_points() -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	var total_points: int = int(SPIRAL_TURNS * SPIRAL_POINTS_PER_TURN)
	points.resize(total_points)

	var theta_max: float = SPIRAL_TURNS * TAU  # TAU = 2π

	for i: int in total_points:
		var theta: float = (float(i) / float(total_points - 1)) * theta_max
		var r: float = SPIRAL_A + SPIRAL_B * (theta / TAU)

		# Góc bắt đầu từ 12 giờ (trừ π/2 để xoay lên trên)
		var x: float = SPIRAL_CENTER.x + r * cos(theta - PI / 2.0)
		var y: float = SPIRAL_CENTER.y + r * sin(theta - PI / 2.0)
		points[i] = Vector2(x, y)

	return points

# ── Private: Sinh tam giác ────────────────────────────────────────────────────

func _generate_triangles() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var theta_max: float = SPIRAL_TURNS * TAU

	# Bước theta giữa các tam giác
	var theta_step: float = TRIANGLE_ANGLE_STEP

	var theta: float = theta_step  # Bắt đầu từ theta_step để tránh khe hở spawn
	while theta < theta_max - theta_step:
		var r: float = SPIRAL_A + SPIRAL_B * (theta / TAU)

		# Vị trí tam giác trên đường spiral
		var x: float = SPIRAL_CENTER.x + r * cos(theta - PI / 2.0)
		var y: float = SPIRAL_CENTER.y + r * sin(theta - PI / 2.0)
		var pos: Vector2 = Vector2(x, y)

		# Góc xoay: hướng đỉnh tam giác vào tâm
		var to_center: Vector2 = (SPIRAL_CENTER - pos).normalized()
		var angle: float = to_center.angle() + PI / 2.0

		# Kích thước scale theo bán kính (vòng ngoài lớn hơn)
		var size: float = r * TRIANGLE_SIZE_RATIO / (SPIRAL_TURNS * TAU / TAU)
		size = clamp(size, 8.0, 35.0)  # Giới hạn min/max

		# Màu cầu vồng theo góc theta (0 → 2π = 1 vòng màu)
		var hue: float = fmod(theta / TAU, 1.0)
		var color: Color = Color.from_hsv(hue, 1.0, 1.0)

		result.append({
			"pos": pos,
			"angle": angle,
			"size": size,
			"color": color,
			"alive": true,
			"collision_radius": size * TRIANGLE_COLLISION_RATIO,
			"theta": theta,
		})

		theta += theta_step

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

## Tính điểm gần nhất trên đoạn thẳng [a, b] so với điểm p.
func _closest_point_on_segment(p: Vector2, a: Vector2, b: Vector2) -> Vector2:
	var ab: Vector2 = b - a
	var ab_len_sq: float = ab.length_squared()
	if ab_len_sq < 0.0001:
		return a  # Segment quá ngắn, trả về điểm a
	var t: float = clamp((p - a).dot(ab) / ab_len_sq, 0.0, 1.0)
	return a + ab * t

## Ước tính index segment gần nhất dựa trên khoảng cách từ tâm.
## Dùng để thu hẹp vùng tìm kiếm trong get_spiral_wall_info().
func _estimate_nearest_segment_index(world_pos: Vector2) -> int:
	var dist_from_center: float = world_pos.distance_to(SPIRAL_CENTER)
	# r = a + b*(theta/TAU) → theta = (r - a) / b * TAU
	var estimated_theta: float = max(0.0, (dist_from_center - SPIRAL_A) / SPIRAL_B * TAU)
	var total_points: int = spiral_points.size()
	var theta_max: float = SPIRAL_TURNS * TAU
	var ratio: float = clamp(estimated_theta / theta_max, 0.0, 1.0)
	return int(ratio * float(total_points - 2))
