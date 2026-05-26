## GameScene.gd
## Script gắn vào GameScene.tscn — node gốc của toàn bộ ứng dụng.
## Khởi tạo GameManager và tự động load mode mặc định.
extends Node2D

@onready var simulation_container: Node2D = $SimulationContainer
@onready var camera: Camera2D = $Camera2D

func _ready() -> void:
	# Kết nối camera zoom TRƯỚC khi start_mode (signal sẽ fire sau khi config load)
	var bus: Node = get_node("/root/EventBus")
	if bus:
		bus.simulation_ready.connect(_apply_camera_zoom)

	# Khởi tạo GameManager — bên trong sẽ load config và emit simulation_ready
	var gm: Node = get_node("/root/GameManager")
	gm.initialize(simulation_container)
	gm.start_mode("spiral")

func _apply_camera_zoom(_mode_id: String = "") -> void:
	var gm: Node = get_node("/root/GameManager")
	if gm and gm.has_method("get_current_config"):
		var cfg: Dictionary = gm.get_current_config()
		var vp: Dictionary = cfg.get("viewport", {})
		var zoom: float = vp.get("camera_zoom", 0.9)
		camera.zoom = Vector2(zoom, zoom)
		
		# Center the camera on the spiral center from the config dynamically
		var spiral_cfg: Dictionary = cfg.get("spiral", {})
		var center_arr: Array = spiral_cfg.get("center", [960.0, 540.0])
		camera.position = Vector2(center_arr[0], center_arr[1])
