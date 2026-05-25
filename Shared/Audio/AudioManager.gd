## AudioManager.gd
## Quản lý âm thanh với pitch escalation.
## Dùng AudioStreamPlayer pool từ ObjectPool — Zero GC.
## Gắn vào GameScene như một Node con.
extends Node

# ── Cấu hình (từ GameManager config) ─────────────────────────────────────────
var _pitch_initial: float = 1.0
var _pitch_increment: float = 0.03
var _pitch_min: float = 0.8
var _pitch_max: float = 2.5
var _pitch_reset_delay: float = 2.0
var _pitch_variation: float = 0.1

func _load_config() -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.has_method("get_current_config"):
		var cfg: Dictionary = gm.get_current_config()
		var ac: Dictionary = cfg.get("audio", {})
		_pitch_initial = ac.get("pitch_initial", 1.0)
		_pitch_increment = ac.get("pitch_increment", 0.03)
		_pitch_min = ac.get("pitch_min", 0.8)
		_pitch_max = ac.get("pitch_max", 2.5)
		_pitch_reset_delay = ac.get("pitch_reset_delay", 2.0)
		_pitch_variation = ac.get("pitch_variation", 0.1)

# ── State ─────────────────────────────────────────────────────────────────────
var _current_pitch: float = _pitch_initial
var _time_since_last_bounce: float = 0.0

# ── Autoload shortcuts ────────────────────────────────────────────────────────
@onready var _event_bus: Node = get_node("/root/EventBus")
@onready var _object_pool: Node = get_node("/root/ObjectPool")

var bounce_stream: AudioStream = null
var brick_stream: AudioStream = null
var fail_stream: AudioStream = null
var win_stream: AudioStream = null
var win_stream_secondary: AudioStream = null

# ── Lifecycle ─────────────────────────────────────────────────────────────────
func _ready() -> void:
	_load_config()
	_try_load_audio()
	_event_bus.ball_bounced.connect(_on_ball_bounced)
	_event_bus.brick_destroyed.connect(_on_brick_destroyed)
	# Reload audio khi simulation mode được setup xong (config đã có)
	_event_bus.simulation_ready.connect(func(_mode_id): _try_load_audio())

func _process(delta: float) -> void:
	_time_since_last_bounce += delta
	if _time_since_last_bounce >= _pitch_reset_delay:
		_current_pitch = _pitch_initial

# ── Signal handlers ───────────────────────────────────────────────────────────

func _on_ball_bounced(_position: Vector2, _normal: Vector2) -> void:
	_time_since_last_bounce = 0.0
	_current_pitch = clamp(_current_pitch + _pitch_increment, _pitch_min, _pitch_max)
	_play_sound(bounce_stream, _current_pitch)

func _on_brick_destroyed(_brick_id: int, _world_position: Vector2, _color: Color) -> void:
	# Phát dry-fart.mp3 khi ball chạm triangle
	var random_pitch: float = _current_pitch + randf_range(-_pitch_variation, _pitch_variation)
	_play_sound(brick_stream, random_pitch)

# ── Public API ────────────────────────────────────────────────────────────────

## Gọi trực tiếp từ SpiralMode — phát âm thanh fail NGAY KHI bị kẹt
func play_fail() -> void:
	_play_sound(fail_stream, 1.0, 3.0)  # +3dB cho fail

## Gọi trực tiếp từ SpiralMode — phát âm thanh win NGAY KHI thắng
func play_win() -> void:
	_play_sound(win_stream, 1.0)
	# Phát âm thanh win thứ cấp sau 0.3s
	if win_stream_secondary:
		var timer: SceneTreeTimer = get_tree().create_timer(0.3)
		timer.timeout.connect(func():
			_play_sound(win_stream_secondary, 1.0)
		)

# ── Private ───────────────────────────────────────────────────────────────────

func _play_sound(stream: AudioStream, pitch: float, volume_boost: float = 0.0) -> void:
	if stream == null:
		return
	var player: AudioStreamPlayer = _object_pool.get_audio_player()
	player.stop()  # Dừng âm thanh trước đó nếu có
	player.stream = stream
	player.pitch_scale = clamp(pitch, _pitch_min, _pitch_max)
	player.volume_db = volume_boost  # Tăng volume nếu cần
	player.play()

func _try_load_audio() -> void:
	# Đọc đường dẫn audio từ config
	var gm = get_node_or_null("/root/GameManager")
	var bounce_path: String = "res://Audio/dry-fart.mp3"
	var brick_path: String = "res://Audio/dry-fart.mp3"
	var fail_path: String = "res://Audio/error-notification.mp3"
	var win_path: String = "res://Audio/check-mark_oPG7Xo5.mp3"
	var win_secondary_path: String = ""
	if gm and gm.has_method("get_current_config"):
		var cfg: Dictionary = gm.get_current_config()
		var ac: Dictionary = cfg.get("audio", {})
		bounce_path = ac.get("bounce_sound_path", bounce_path)
		brick_path = ac.get("brick_sound_path", brick_path)
		fail_path = ac.get("fail_sound_path", fail_path)
		win_path = ac.get("win_sound_path", win_path)
		win_secondary_path = ac.get("win_sound_secondary_path", win_secondary_path)

	bounce_stream = _load_or_generate(bounce_path, 800, 0.08)
	brick_stream = _load_or_generate(brick_path, 600, 0.1)
	fail_stream = _load_or_generate(fail_path, 400, 0.3)
	win_stream = _load_or_generate(win_path, 1000, 0.5)
	win_stream_secondary = _load_or_generate(win_secondary_path, 1000, 0.5) if not win_secondary_path.is_empty() else null

## Tải file audio. Trả về null nếu file không tồn tại (không tạo placeholder)
func _load_or_generate(path: String, _freq: float, _duration: float) -> AudioStream:
	if ResourceLoader.exists(path):
		return load(path)
	print('[AudioManager] ⚠️ Không tìm thấy "%s" — bỏ qua' % path)
	return null
