## ScreenShake.gd
## Utility node — gắn vào SpiralMode, tìm Camera2D trong scene tree và rung nó.
extends Node

# ── Hằng số ───────────────────────────────────────────────────────────────────
const DECAY_TIME: float = 0.15    # Thời gian rung tắt dần (giây)
const MAX_INTENSITY: float = 8.0  # Giới hạn intensity tối đa (px)

# ── State ─────────────────────────────────────────────────────────────────────
var _camera: Camera2D = null
var _original_offset: Vector2 = Vector2.ZERO
var _current_intensity: float = 0.0
var _tween: Tween = null

# ── Lifecycle ─────────────────────────────────────────────────────────────────
func _ready() -> void:
	# Tìm Camera2D trong scene tree (ở GameScene)
	_camera = get_tree().get_first_node_in_group("main_camera")
	if _camera == null:
		# Fallback: tìm theo type
		_camera = _find_camera(get_tree().root)

func _process(delta: float) -> void:
	if _camera == null or _current_intensity <= 0.0:
		return

	# Áp dụng offset ngẫu nhiên theo intensity hiện tại
	var offset: Vector2 = Vector2(
		randf_range(-_current_intensity, _current_intensity),
		randf_range(-_current_intensity, _current_intensity)
	)
	_camera.offset = offset

# ── Public API ────────────────────────────────────────────────────────────────

## Kích hoạt screen shake với intensity cho trước.
## intensity: độ rung tính bằng pixel
func shake(intensity: float) -> void:
	if _camera == null:
		return

	_current_intensity = min(intensity, MAX_INTENSITY)

	# Hủy tween cũ nếu đang chạy
	if _tween != null and _tween.is_valid():
		_tween.kill()

	# Tween decay intensity về 0
	_tween = create_tween()
	_tween.tween_property(self, "_current_intensity", 0.0, DECAY_TIME)
	_tween.tween_callback(_reset_camera_offset)

# ── Private ───────────────────────────────────────────────────────────────────

func _reset_camera_offset() -> void:
	if _camera != null:
		_camera.offset = Vector2.ZERO
	_current_intensity = 0.0

func _find_camera(node: Node) -> Camera2D:
	if node is Camera2D:
		return node as Camera2D
	for child: Node in node.get_children():
		var result: Camera2D = _find_camera(child)
		if result != null:
			return result
	return null
