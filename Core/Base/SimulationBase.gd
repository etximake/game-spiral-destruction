## SimulationBase.gd
## Abstract base class cho mọi Simulation Mode.
## Mỗi mode mới phải extends class này và override các hàm bên dưới.
## Đảm bảo interface nhất quán để GameManager có thể gọi mà không cần biết mode cụ thể.
extends Node2D

# ── Config (được set bởi GameManager khi load mode) ──────────────────────────
var _config: Dictionary = {}

## Set config từ ModeConfigLoader. Gọi trước setup().
func set_config(config: Dictionary) -> void:
	_config = config

# ── Interface bắt buộc override ───────────────────────────────────────────────

## Gọi một lần khi scene được load vào SimulationContainer.
## Dùng để: sinh geometry, pre-compute data, khởi tạo spatial grid.
## KHÔNG bắt đầu animation hay movement ở đây.
func setup() -> void:
	push_warning("SimulationBase.setup() chưa được override bởi: " + get_script().resource_path)

## Gọi sau setup() để bắt đầu simulation chạy.
## Dùng để: set velocity bóng, bắt đầu timer, enable physics processing.
func start() -> void:
	push_warning("SimulationBase.start() chưa được override bởi: " + get_script().resource_path)

## Gọi khi người dùng nhấn Reset.
## KHÔNG reload scene — chỉ reset state về giá trị ban đầu.
## Phải hoàn thành trong < 0.5 giây (không có async).
func reset() -> void:
	push_warning("SimulationBase.reset() chưa được override bởi: " + get_script().resource_path)

## Gọi khi win condition đạt được.
## Dùng để: phát win effects, emit simulation_completed signal.
func on_completed() -> void:
	push_warning("SimulationBase.on_completed() chưa được override bởi: " + get_script().resource_path)

# ── Helper dùng chung cho mọi mode ───────────────────────────────────────────

## Emit simulation_completed với thời gian đã chạy.
func _emit_completed() -> void:
	var game_manager: Node = get_node("/root/GameManager")
	var event_bus: Node = get_node("/root/EventBus")
	var duration: float = game_manager.get_elapsed_time()
	event_bus.simulation_completed.emit(game_manager.current_mode_id, duration)
