## GameScene.gd
## Script gắn vào GameScene.tscn — node gốc của toàn bộ ứng dụng.
## Khởi tạo GameManager và tự động load mode mặc định.
extends Node2D

@onready var simulation_container: Node2D = $SimulationContainer
@onready var camera: Camera2D = $Camera2D

func _ready() -> void:
	# Đọc camera_zoom từ config
	var gm: Node = get_node("/root/GameManager")
	if gm and gm.has_method("get_current_config"):
		var cfg: Dictionary = gm.get_current_config()
		var vp: Dictionary = cfg.get("viewport", {})
		var zoom: float = vp.get("camera_zoom", 0.9)
		camera.zoom = Vector2(zoom, zoom)
	
	gm.initialize(simulation_container)
	gm.start_mode("spiral")
