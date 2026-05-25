## GlassDebris.gd
## Tạo hiệu ứng vỡ vụn kính/tam giác thành 3 mảnh ngẫu nhiên, xoay và rơi tự do.
## Optimized: gộp tất cả shard vào 1 mesh draw call, bỏ outline riêng lẻ.
## Style: Neon hollow glow — đồng bộ với triangles (outer_brightness, inner_alpha, hollow_scale).
extends Node2D

# Cấu hình (đọc từ GameManager config khi activate)
var _lifetime: float = 0.6
var _gravity: float = 450.0
var _num_shards: int = 3
var _outer_brightness: float = 2.5
var _inner_brightness: float = 0.3
var _inner_alpha: float = 0.9
var _hollow_scale: float = 0.7

# Class đại diện cho một mảnh vỡ
class Shard:
	var position: Vector2
	var velocity: Vector2
	var rotation: float
	var rotation_speed: float
	var size: float = 1.0

# Mesh tĩnh được tạo 1 lần, dùng chung cho mọi debris
var _base_mesh: ArrayMesh = null
var _shards: Array[Shard] = []
var _time_elapsed: float = 0.0
var _color: Color = Color.WHITE
var _is_active: bool = false

func _ready() -> void:
	set_process(false)
	# Tạo base mesh 1 lần — neon hollow triangle
	if _base_mesh == null:
		_base_mesh = _create_shard_mesh()

func activate(color: Color) -> void:
	_color = color
	_time_elapsed = 0.0
	_is_active = true
	
	# Đọc config từ GameManager
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.has_method("get_current_config"):
		var cfg: Dictionary = gm.get_current_config()
		var dc: Dictionary = cfg.get("debris", {})
		_lifetime = dc.get("lifetime", 0.6)
		_gravity = dc.get("gravity", 450.0)
		_num_shards = dc.get("num_shards", 3)
		var sizes: Array = dc.get("shard_sizes", [20.0, 40.0])
		var speeds: Array = dc.get("launch_speed", [160.0, 480.0])
		var rot_speeds: Array = dc.get("rotation_speed", [-12.0, 12.0])
		
		# Đọc style neon từ triangle mesh config — đồng bộ với triangles
		var tri_cfg: Dictionary = cfg.get("triangles", {})
		var mesh_cfg: Dictionary = tri_cfg.get("mesh", {})
		_outer_brightness = mesh_cfg.get("outer_brightness", 2.5)
		_inner_brightness = mesh_cfg.get("inner_brightness", 0.3)
		_inner_alpha = mesh_cfg.get("inner_alpha", 0.9)
		_hollow_scale = mesh_cfg.get("hollow_scale", 0.7)
		
		# Tạo lại mesh nếu config thay đổi
		if _base_mesh != null:
			_base_mesh = _create_shard_mesh()
		
		# Tái sử dụng shard array
		_shards.resize(_num_shards)
		for i in _num_shards:
			if _shards[i] == null:
				_shards[i] = Shard.new()
			var shard: Shard = _shards[i]
			shard.position = Vector2.ZERO
			var launch_angle: float = randf_range(0.0, TAU)
			var speed: float = randf_range(speeds[0], speeds[1])
			shard.velocity = Vector2(cos(launch_angle), sin(launch_angle)) * speed
			shard.rotation = randf_range(0.0, TAU)
			shard.rotation_speed = randf_range(rot_speeds[0], rot_speeds[1])
			shard.size = randf_range(sizes[0], sizes[1])
	
	set_process(true)
	queue_redraw()

func _process(delta: float) -> void:
	if not _is_active:
		return
		
	_time_elapsed += delta
	if _time_elapsed >= _lifetime:
		_is_active = false
		set_process(false)
		visible = false
		return
		
	for shard in _shards:
		shard.velocity.y += _gravity * delta
		shard.position += shard.velocity * delta
		shard.rotation += shard.rotation_speed * delta
		
	queue_redraw()

func _draw() -> void:
	if not _is_active or _shards.is_empty() or _base_mesh == null:
		return
		
	var alpha: float = clamp(1.0 - (_time_elapsed / _lifetime), 0.0, 1.0)
	var draw_color := Color(_color.r, _color.g, _color.b, alpha * _color.a)
	
	# Vẽ tất cả shard trong 1 draw call — mỗi shard là 1 instance của base mesh
	for shard in _shards:
		var scale_factor: float = shard.size / 30.0  # 30.0 = base mesh size reference
		draw_set_transform(shard.position, shard.rotation, Vector2(scale_factor, scale_factor))
		draw_mesh(_base_mesh, null, Transform2D(), draw_color)
		
	# Khôi phục transform mặc định
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## Tạo mesh mảnh vỡ hình tam giác neon hollow — style đồng bộ với triangles.
## Gồm 6 đỉnh ngoài + 6 đỉnh trong tạo viền phát sáng.
func _create_shard_mesh() -> ArrayMesh:
	var mesh: ArrayMesh = ArrayMesh.new()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	
	# Kích thước cơ sở: 30px
	var s: float = 30.0
	# Tỉ lệ tam giác nhọn: đỉnh cao, đáy rộng
	var h: float = 0.866025 * s
	var apex: Vector2 = Vector2(0.0, -h * 0.6)          # Đỉnh nhọn
	var corner_l: Vector2 = Vector2(-s * 0.4, h * 0.4)  # Góc trái
	var corner_r: Vector2 = Vector2(s * 0.4, h * 0.4)   # Góc phải
	var mid_l: Vector2 = Vector2(-s * 0.2, 0.0)         # Điểm giữa trái
	var mid_r: Vector2 = Vector2(s * 0.2, 0.0)          # Điểm giữa phải
	var base_mid: Vector2 = Vector2(0.0, h * 0.2)       # Giữa đáy
	
	# 6 đỉnh ngoài tạo hình mảnh vỡ
	var vertices_out: PackedVector2Array = PackedVector2Array([
		apex,
		corner_l,
		mid_l,
		base_mid,
		mid_r,
		corner_r,
	])
	
	var uvs_out: PackedVector2Array = PackedVector2Array([
		Vector2(0.5, 0.0),
		Vector2(0.0, 1.0),
		Vector2(0.25, 0.5),
		Vector2(0.5, 0.8),
		Vector2(0.75, 0.5),
		Vector2(1.0, 1.0),
	])
	
	# Tạo 12 đỉnh (6 ngoài, 6 trong)
	var vertices: PackedVector2Array = PackedVector2Array()
	vertices.resize(12)
	var uvs: PackedVector2Array = PackedVector2Array()
	uvs.resize(12)
	var colors: PackedColorArray = PackedColorArray()
	colors.resize(12)
	
	var outer_color: Color = Color(_outer_brightness, _outer_brightness, _outer_brightness, 1.0)
	var inner_color: Color = Color(_inner_brightness, _inner_brightness, _inner_brightness, _inner_alpha)
	
	for i: int in 6:
		vertices[i] = vertices_out[i]
		uvs[i] = uvs_out[i]
		colors[i] = outer_color
		
		vertices[i + 6] = vertices_out[i] * _hollow_scale
		uvs[i + 6] = Vector2(0.5, 0.5) + (uvs_out[i] - Vector2(0.5, 0.5)) * _hollow_scale
		colors[i + 6] = inner_color
	
	# Triangulation
	var indices: PackedInt32Array = PackedInt32Array()
	
	# Inner fan (4 triangles)
	indices.append(6); indices.append(7); indices.append(8)
	indices.append(6); indices.append(8); indices.append(9)
	indices.append(6); indices.append(9); indices.append(10)
	indices.append(6); indices.append(10); indices.append(11)
	
	# Outer ring (12 triangles — 2 per segment)
	for j: int in 6:
		var next_j: int = (j + 1) % 6
		indices.append(j)
		indices.append(next_j)
		indices.append(j + 6)
		indices.append(next_j)
		indices.append(next_j + 6)
		indices.append(j + 6)
	
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
