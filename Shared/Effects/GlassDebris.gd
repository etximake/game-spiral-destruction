## GlassDebris.gd
## Tạo hiệu ứng vỡ vụn kính/tam giác thành 3 mảnh ngẫu nhiên, xoay và rơi tự do.
## Optimized: gộp tất cả shard vào 1 mesh draw call, bỏ outline riêng lẻ.
extends Node2D

# Cấu hình (đọc từ GameManager config khi activate)
var _lifetime: float = 0.6
var _gravity: float = 450.0
var _num_shards: int = 3

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
	# Tạo base mesh 1 lần — 3 tam giác, 9 đỉnh
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

## Tạo mesh chứa 1 tam giác sắc nhọn — được reuse cho mỗi shard
func _create_shard_mesh() -> ArrayMesh:
	var mesh: ArrayMesh = ArrayMesh.new()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	
	# Một tam giác duy nhất (3 đỉnh)
	var verts: PackedVector2Array = PackedVector2Array([
		Vector2.ZERO,
		Vector2(20.0, -10.0),
		Vector2(10.0, 20.0),
	])
	var indices: PackedInt32Array = [0, 1, 2]
	
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
