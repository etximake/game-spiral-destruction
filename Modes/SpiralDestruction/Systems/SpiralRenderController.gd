## SpiralRenderController.gd
## Quản lý toàn bộ rendering của spiral mode.
extends Node2D

# ── Config ────────────────────────────────────────────────────────────────────
var _tri_cfg: Dictionary = {}

func set_config(config: Dictionary) -> void:
	_tri_cfg = config.get("triangles", {})
	var tri_mesh: Dictionary = _tri_cfg.get("mesh", {})
	_mesh_outer_color = Color(tri_mesh.get("outer_brightness", 2.5), tri_mesh.get("outer_brightness", 2.5), tri_mesh.get("outer_brightness", 2.5), 1.0)
	_mesh_inner_color = Color(tri_mesh.get("inner_brightness", 0.1), tri_mesh.get("inner_brightness", 0.1), tri_mesh.get("inner_brightness", 0.1), tri_mesh.get("inner_alpha", 0.2))
	_mesh_hollow_scale = tri_mesh.get("hollow_scale", 0.75)
	var spawn_anim: Dictionary = _tri_cfg.get("spawn_animation", {})
	_spawn_wave_duration = spawn_anim.get("wave_duration", 0.35)
	_spawn_scale_up_duration = spawn_anim.get("scale_up_duration", 0.15)
	_regrow_duration = spawn_anim.get("regrow_duration", 0.5)
	
	var spiral_cfg: Dictionary = config.get("spiral", {})
	_spiral_line_color = _arr_to_color(spiral_cfg.get("line_color", [1.0, 1.0, 1.0, 0.6]), Color(1, 1, 1, 0.6))
	_spiral_line_width = spiral_cfg.get("line_width", 4.0)

# ── Configurable visuals ──────────────────────────────────────────────────────
var _mesh_outer_color: Color = Color(2.5, 2.5, 2.5, 1.0)
var _mesh_inner_color: Color = Color(0.1, 0.1, 0.1, 0.2)
var _mesh_hollow_scale: float = 0.75
var _spawn_wave_duration: float = 0.35
var _spawn_scale_up_duration: float = 0.15
var _regrow_duration: float = 0.5
var _spiral_line_color: Color = Color(1, 1, 1, 0.6)
var _spiral_line_width: float = 4.0

# ── Node references ───────────────────────────────────────────────────────────
var _multimesh_instance: MultiMeshInstance2D = null
var _multimesh: MultiMesh = null
var _spiral_line: Line2D = null

# ── Internal state ────────────────────────────────────────────────────────────
var _total_instances: int = 0
var _instance_scales: PackedFloat32Array = PackedFloat32Array()
var _map_controller_ref: Node = null
var _spawn_anim_active: bool = false
var _spawn_anim_time: float = 0.0
var _last_wave_index: int = 0

# ── Regrow animation state ────────────────────────────────────────────────────
var _regrow_active: bool = false
var _regrow_time: float = 0.0
var _regrow_ids: Array[int] = []
var _regrow_sorted: Array[int] = []  # destroyed ids sorted inside→out

# ── Lifecycle ─────────────────────────────────────────────────────────────────
func _ready() -> void:
	set_process(false)

func _process(delta: float) -> void:
	# Ưu tiên xử lý spawn animation
	if _spawn_anim_active:
		_process_spawn_anim(delta)
		return
	
	# Xử lý regrow animation
	if _regrow_active:
		_process_regrow_anim(delta)
		return
	
	set_process(false)

func _process_spawn_anim(delta: float) -> void:
	_spawn_anim_time += delta
	var all_done: bool = true
	
	# Tính toán wave index hiện tại
	var wave_progress: float = _spawn_anim_time / _spawn_wave_duration
	var current_wave_end: int = min(_total_instances, int(wave_progress * _total_instances) + 1)
	
	# Chạy từ _last_wave_index đến current_wave_end
	for i: int in range(_last_wave_index, current_wave_end):
		var delay: float = (float(i) / float(_total_instances)) * _spawn_wave_duration
		var elapsed: float = _spawn_anim_time - delay
		var target_scale: float = clamp(elapsed / _spawn_scale_up_duration, 0.0, 1.0)
		
		if target_scale < 1.0:
			all_done = false
		
		if target_scale != _instance_scales[i]:
			_instance_scales[i] = target_scale
			var tri: Dictionary = _map_controller_ref.triangles[i]
			if tri["alive"]:
				_set_instance_from_data(i, tri)
	
	# Cũng kiểm tra các instance phía trước để xem có done chưa
	if current_wave_end >= _total_instances:
		for i: int in range(_last_wave_index, _total_instances):
			if _instance_scales[i] < 1.0:
				all_done = false
				break
	else:
		all_done = false
	
	_last_wave_index = max(_last_wave_index, current_wave_end)
				
	if all_done or _spawn_anim_time >= _spawn_wave_duration + _spawn_scale_up_duration:
		_spawn_anim_active = false
		set_process(false)
		# Force set all alive instances to scale 1.0 exactly
		for i: int in _total_instances:
			_instance_scales[i] = 1.0
			var tri: Dictionary = _map_controller_ref.triangles[i]
			if tri["alive"]:
				_set_instance_from_data(i, tri)

func _process_regrow_anim(delta: float) -> void:
	_regrow_time += delta
	var all_done: bool = true
	var count: int = _regrow_sorted.size()
	
	for idx: int in count:
		var tri_id: int = _regrow_sorted[idx]
		# Mỗi tam giác có delay dựa trên thứ tự từ trong→ngoài
		var delay: float = (float(idx) / float(count)) * _regrow_duration * 0.5
		var elapsed: float = _regrow_time - delay
		
		if elapsed <= 0.0:
			all_done = false
			continue
		
		var progress: float = clamp(elapsed / 0.25, 0.0, 1.0)
		
		if progress < 1.0:
			all_done = false
		
		if progress != _instance_scales[tri_id]:
			_instance_scales[tri_id] = progress
			var tri: Dictionary = _map_controller_ref.triangles[tri_id]
			_regrow_set_instance_from_data(tri_id, tri, progress)
	
	# Kiểm tra các tam giác đã hoàn thành
	if not all_done:
		return
	
	# Hoàn tất regrow
	_regrow_active = false
	set_process(false)
	for tri_id: int in _regrow_ids:
		_instance_scales[tri_id] = 1.0
		var tri: Dictionary = _map_controller_ref.triangles[tri_id]
		_set_instance_from_data(tri_id, tri)
	_regrow_ids.clear()
	_regrow_sorted.clear()

# ── Public API ────────────────────────────────────────────────────────────────

## Khởi tạo toàn bộ renderer từ dữ liệu của SpiralMapController.
## Gọi một lần trong SpiralMode.setup().
func setup(map_controller: Node) -> void:
	_map_controller_ref = map_controller
	# Triangles trước → ở dưới, Spiral line sau → ở trên
	_setup_multimesh(map_controller.triangles)
	_setup_spiral_line(map_controller.spiral_points)

## Kích hoạt regrow animation cho các tam giác đã bị phá hủy.
## Chỉ những triangle trong destroyed_ids mới animate — các triangle còn sống giữ nguyên.
## Thứ tự: từ trong ra ngoài (gần tâm → xa tâm).
## Mọc từ đường spiral (base_pos) đến vị trí cuối (pos).
func play_regrow_animation(destroyed_ids: Array[int]) -> void:
	if destroyed_ids.is_empty():
		return
	
	# Sắp xếp từ trong ra ngoài (gần tâm SPIRAL_CENTER trước)
	var center: Vector2 = _map_controller_ref.SPIRAL_CENTER
	_regrow_sorted = destroyed_ids.duplicate()
	_regrow_sorted.sort_custom(func(a: int, b: int) -> bool:
		var da: float = _map_controller_ref.triangles[a]["pos"].distance_squared_to(center)
		var db: float = _map_controller_ref.triangles[b]["pos"].distance_squared_to(center)
		return da < db
	)
	
	_regrow_ids = destroyed_ids.duplicate()
	_regrow_time = 0.0
	_regrow_active = true
	
	# Set các tam giác bị phá về scale 0 trước khi animate
	for tri_id: int in _regrow_ids:
		_instance_scales[tri_id] = 0.0
		_multimesh.set_instance_transform_2d(tri_id, Transform2D(0.0, Vector2.ZERO, 0.0, Vector2.ZERO))
	
	set_process(true)

## Kích hoạt hoạt ảnh xuất hiện của tam giác (scale từ 0.0 -> 1.0)
func play_spawn_animation() -> void:
	_spawn_anim_active = true
	_spawn_anim_time = 0.0
	_last_wave_index = 0
	
	# Set all instance scales to 0.0 initially
	for i: int in _total_instances:
		_instance_scales[i] = 0.0
		var tri: Dictionary = _map_controller_ref.triangles[i]
		_set_instance_from_data(i, tri)
		
	set_process(true)

## Ẩn một tam giác (khi bị phá hủy).
## Dùng scale = 0 thay vì xóa instance — Zero GC.
func hide_triangle(triangle_id: int) -> void:
	if triangle_id < 0 or triangle_id >= _total_instances:
		return
	_instance_scales[triangle_id] = 0.0
	# Transform2D(rotation, scale, skew, position) — scale 0 = tàng hình
	_multimesh.set_instance_transform_2d(triangle_id, Transform2D(0.0, Vector2.ZERO, 0.0, Vector2.ZERO))

## Khôi phục tất cả tam giác (khi reset).
func restore_all(triangles: Array[Dictionary]) -> void:
	for i: int in triangles.size():
		_instance_scales[i] = 1.0
		_set_instance_from_data(i, triangles[i])

## Thiết lập tỷ lệ scale tạm thời cho một hoặc tất cả instance (phục vụ animation xuất hiện)
func set_instance_scale_multiplier(instance_id: int, multiplier: float, data: Dictionary) -> void:
	if instance_id < 0 or instance_id >= _total_instances:
		return
	_instance_scales[instance_id] = multiplier
	if data["alive"]:
		_set_instance_from_data(instance_id, data)

# ── Private: MultiMesh setup ──────────────────────────────────────────────────

func _setup_multimesh(triangles: Array[Dictionary]) -> void:
	_total_instances = triangles.size()
	_instance_scales.resize(_total_instances)
	_instance_scales.fill(1.0)

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

## Tạo mesh tam giác có cạnh đáy uốn cong dạng khiên rỗng với viền neon phát sáng.
## Gồm 12 đỉnh (6 ngoài, 6 trong). Vòng ngoài có màu sáng HDR phát sáng, vòng trong bán trong suốt.
func _create_triangle_mesh() -> ArrayMesh:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)

	# Chiều cao và các mốc Y chuẩn của tam giác đều cạnh = 1.0
	var h: float = 0.866025
	var y_base: float = h * 0.333333    # Mốc cạnh đáy phẳng cũ (y ≈ 0.2887)
	var y_apex: float = -h * 0.666667   # Đỉnh tam giác (y ≈ -0.5774)

	# Tâm uốn cong (nằm phía trên đỉnh tam giác ở hệ tọa độ local)
	# Với y_center = 1.8, cạnh đáy sẽ cong lõm vào trong (corners kéo lên gần đỉnh)
	var y_center: float = 1.8
	var r_local: float = y_base + y_center # Bán kính đường tròn cung đáy

	# Tính tọa độ Y của góc và điểm trung gian để tạo cung tròn đều
	var y_corner: float = sqrt(r_local * r_local - 0.25) - y_center  # tại x = ±0.5
	var y_mid: float = sqrt(r_local * r_local - 0.0625) - y_center  # tại x = ±0.25

	# 6 đỉnh ngoài tạo thành đa giác khiên với cung đáy cong
	var vertices_out: PackedVector2Array = PackedVector2Array([
		Vector2(0.0, y_apex),       # 0: Đỉnh (Apex)
		Vector2(-0.5, y_corner),    # 1: Góc trái dưới
		Vector2(-0.25, y_mid),      # 2: Điểm giữa trái
		Vector2(0.0, y_base),       # 3: Giữa cạnh đáy
		Vector2(0.25, y_mid),       # 4: Điểm giữa phải
		Vector2(0.5, y_corner),     # 5: Góc phải dưới
	])

	# Khai báo UV ngoài tương ứng
	var uvs_out: PackedVector2Array = PackedVector2Array([
		Vector2(0.5, 0.0),
		Vector2(0.0, 1.0),
		Vector2(0.25, 1.0),
		Vector2(0.5, 1.0),
		Vector2(0.75, 1.0),
		Vector2(1.0, 1.0),
	])

	# Tạo 12 đỉnh (6 ngoài, 6 trong)
	var vertices: PackedVector2Array = PackedVector2Array()
	vertices.resize(12)
	var uvs: PackedVector2Array = PackedVector2Array()
	uvs.resize(12)
	var colors: PackedColorArray = PackedColorArray()
	colors.resize(12)

	# Hệ số scale phần rỗng bên trong (viền neon dày 25% kích thước)
	var scale_factor: float = _mesh_hollow_scale

	for i: int in 6:
		# Đỉnh ngoài
		vertices[i] = vertices_out[i]
		uvs[i] = uvs_out[i]
		# Đỉnh ngoài màu neon sặc sỡ (từ config)
		colors[i] = _mesh_outer_color

		# Đỉnh trong (scale thu nhỏ về tâm (0,0))
		vertices[i + 6] = vertices_out[i] * scale_factor
		uvs[i + 6] = Vector2(0.5, 0.5) + (uvs_out[i] - Vector2(0.5, 0.5)) * scale_factor
		# Phần ruột rỗng bán trong suốt để nổi bật viền (từ config)
		colors[i + 6] = _mesh_inner_color

	# Triangulation
	var indices: PackedInt32Array = PackedInt32Array()

	# 1. Phần quạt bên trong (Inner Fan - 4 tam giác)
	indices.append(6)
	indices.append(7)
	indices.append(8)

	indices.append(6)
	indices.append(8)
	indices.append(9)

	indices.append(6)
	indices.append(9)
	indices.append(10)

	indices.append(6)
	indices.append(10)
	indices.append(11)

	# 2. Vòng viền ngoài nối giữa ngoài và trong (Ring - 12 tam giác)
	for j: int in 6:
		var next_j: int = (j + 1) % 6
		# Tam giác 1 (outer j -> outer next -> inner j)
		indices.append(j)
		indices.append(next_j)
		indices.append(j + 6)
		# Tam giác 2 (outer next -> inner next -> inner j)
		indices.append(next_j)
		indices.append(next_j + 6)
		indices.append(j + 6)

	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

## Gán transform cho instance với regrow: nội suy vị trí từ base_pos → pos theo progress
func _regrow_set_instance_from_data(instance_id: int, data: Dictionary, progress: float) -> void:
	if not data["alive"] or _instance_scales[instance_id] <= 0.0001:
		_multimesh.set_instance_transform_2d(instance_id, Transform2D(0.0, Vector2.ZERO, 0.0, Vector2.ZERO))
		return
	
	# Nội suy vị trí từ base_pos (trên đường spiral) đến pos (vị trí cuối)
	var start_pos: Vector2 = data["base_pos"]
	var end_pos: Vector2 = data["pos"]
	var pos: Vector2 = start_pos.lerp(end_pos, progress)
	
	var angle: float = data["angle"]
	var size: float = data["size"] * _instance_scales[instance_id]
	var color: Color = data["color"]

	var transform: Transform2D = Transform2D(angle, Vector2(size, size), 0.0, pos)
	_multimesh.set_instance_transform_2d(instance_id, transform)
	_multimesh.set_instance_color(instance_id, color)

## Gán transform và màu cho một instance từ dữ liệu tam giác.
func _set_instance_from_data(instance_id: int, data: Dictionary) -> void:
	if not data["alive"] or _instance_scales[instance_id] <= 0.0001:
		_multimesh.set_instance_transform_2d(instance_id, Transform2D(0.0, Vector2.ZERO, 0.0, Vector2.ZERO))
		return

	var pos: Vector2 = data["pos"]
	var angle: float = data["angle"]
	var size: float = data["size"] * _instance_scales[instance_id]
	var color: Color = data["color"]

	# Tạo Transform2D: xoay + scale + dịch chuyển
	var transform: Transform2D = Transform2D(angle, Vector2(size, size), 0.0, pos)
	_multimesh.set_instance_transform_2d(instance_id, transform)
	_multimesh.set_instance_color(instance_id, color)

# ── Private: Spiral Line ──────────────────────────────────────────────────────

func _setup_spiral_line(spiral_points: PackedVector2Array) -> void:
	_spiral_line = Line2D.new()
	_spiral_line.points = spiral_points
	_spiral_line.width = _spiral_line_width
	_spiral_line.default_color = _spiral_line_color
	_spiral_line.antialiased = true
	
	# Tạo rainbow gradient cho spiral line — đồng bộ màu với triangles
	var hue_start: float = _tri_cfg.get("color_hue_start", 0.8)
	var hue_range: float = _tri_cfg.get("color_hue_range", 1.0)
	var gradient: Gradient = Gradient.new()
	var num_stops: int = 12
	for i: int in num_stops:
		var t: float = float(i) / float(num_stops - 1)
		var hue: float = fmod(hue_start + t * hue_range, 1.0)
		var c: Color = Color.from_hsv(hue, 1.0, 1.0, 0.8)
		gradient.add_point(t, c)
	_spiral_line.gradient = gradient
	add_child(_spiral_line)

## Helper: chuyển mảng màu thành Color
static func _arr_to_color(arr: Array, default_color: Color) -> Color:
	if arr.size() < 3:
		return default_color
	if arr.size() == 3:
		return Color(arr[0], arr[1], arr[2])
	return Color(arr[0], arr[1], arr[2], arr[3])

