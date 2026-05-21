## SpiralRenderController.gd
## Quản lý toàn bộ rendering của spiral mode.
extends Node2D

# ── Node references ───────────────────────────────────────────────────────────
## MultiMeshInstance2D — node con, tạo trong _setup_multimesh()
var _multimesh_instance: MultiMeshInstance2D = null
var _multimesh: MultiMesh = null

## Line2D cho đường spiral wall
var _spiral_line: Line2D = null

# ── Internal state ────────────────────────────────────────────────────────────
var _total_instances: int = 0

# ── Public API ────────────────────────────────────────────────────────────────

## Khởi tạo toàn bộ renderer từ dữ liệu của SpiralMapController.
## Gọi một lần trong SpiralMode.setup().
func setup(map_controller: SpiralMapController) -> void:
	_setup_spiral_line(map_controller.spiral_points)
	_setup_multimesh(map_controller.triangles)

## Ẩn một tam giác (khi bị phá hủy).
## Dùng scale = 0 thay vì xóa instance — Zero GC.
func hide_triangle(triangle_id: int) -> void:
	if triangle_id < 0 or triangle_id >= _total_instances:
		return
	# Transform2D(rotation, scale, skew, position) — scale 0 = tàng hình
	_multimesh.set_instance_transform_2d(triangle_id, Transform2D(0.0, Vector2.ZERO, 0.0, Vector2.ZERO))

## Khôi phục tất cả tam giác (khi reset).
func restore_all(triangles: Array[Dictionary]) -> void:
	for i: int in triangles.size():
		_set_instance_from_data(i, triangles[i])

# ── Private: MultiMesh setup ──────────────────────────────────────────────────

func _setup_multimesh(triangles: Array[Dictionary]) -> void:
	_total_instances = triangles.size()

	# Tạo mesh hình tam giác cân nhọn (đỉnh hướng lên, base ở dưới)
	# Sẽ được xoay đúng hướng qua Transform2D của từng instance
	var mesh: ArrayMesh = _create_triangle_mesh()

	# Tạo MultiMesh
	_multimesh = MultiMesh.new()
	_multimesh.transform_format = MultiMesh.TRANSFORM_2D
	_multimesh.use_colors = true          # Cho phép màu per-instance
	_multimesh.instance_count = _total_instances
	_multimesh.mesh = mesh

	# Upload transform + color cho từng instance
	for i: int in _total_instances:
		_set_instance_from_data(i, triangles[i])

	# Tạo MultiMeshInstance2D node
	_multimesh_instance = MultiMeshInstance2D.new()
	_multimesh_instance.multimesh = _multimesh
	add_child(_multimesh_instance)

## Tạo mesh tam giác cân nhọn chuẩn hóa (size = 1.0).
## Scale thực tế được áp dụng qua Transform2D của từng instance.
func _create_triangle_mesh() -> ArrayMesh:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)

	# Tam giác cân: đỉnh ở trên (0, -1), 2 góc dưới (-0.5, 0.5) và (0.5, 0.5)
	# Tỉ lệ nhọn: chiều cao = 1.4 × base để tạo hình spike
	var vertices: PackedVector2Array = PackedVector2Array([
		Vector2(0.0, -1.4),    # Đỉnh nhọn (hướng vào tâm sau khi xoay)
		Vector2(-0.5, 0.5),    # Góc trái
		Vector2(0.5, 0.5),     # Góc phải
	])

	# UV (không dùng texture nhưng cần khai báo)
	var uvs: PackedVector2Array = PackedVector2Array([
		Vector2(0.5, 0.0),
		Vector2(0.0, 1.0),
		Vector2(1.0, 1.0),
	])

	# Index
	var indices: PackedInt32Array = PackedInt32Array([0, 1, 2])

	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

## Gán transform và màu cho một instance từ dữ liệu tam giác.
func _set_instance_from_data(instance_id: int, data: Dictionary) -> void:
	var pos: Vector2 = data["pos"]
	var angle: float = data["angle"]
	var size: float = data["size"]
	var color: Color = data["color"]

	# Tạo Transform2D: xoay + scale + dịch chuyển
	var transform: Transform2D = Transform2D(angle, Vector2(size, size), 0.0, pos)
	_multimesh.set_instance_transform_2d(instance_id, transform)
	_multimesh.set_instance_color(instance_id, color)

# ── Private: Spiral Line ──────────────────────────────────────────────────────

func _setup_spiral_line(spiral_points: PackedVector2Array) -> void:
	_spiral_line = Line2D.new()
	_spiral_line.points = spiral_points
	_spiral_line.width = 2.0
	_spiral_line.default_color = Color(1.0, 1.0, 1.0, 0.6)  # Trắng, opacity 60%
	_spiral_line.antialiased = true
	add_child(_spiral_line)
	# Đặt spiral line phía sau multimesh
	move_child(_spiral_line, 0)
