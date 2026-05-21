## GameScene.gd
## Script gắn vào GameScene.tscn — node gốc của toàn bộ ứng dụng.
## Khởi tạo GameManager và tự động load mode mặc định.
extends Node2D

@onready var simulation_container: Node2D = $SimulationContainer
@onready var camera: Camera2D = $Camera2D

func _ready() -> void:
	var game_manager: Node = get_node("/root/GameManager")
	game_manager.initialize(simulation_container)
	game_manager.start_mode("spiral")
