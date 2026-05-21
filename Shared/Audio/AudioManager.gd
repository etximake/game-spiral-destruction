## AudioManager.gd
## Quản lý âm thanh với pitch escalation.
## Dùng AudioStreamPlayer pool từ ObjectPool — Zero GC.
## Gắn vào GameScene như một Node con.
extends Node

# ── Hằng số ───────────────────────────────────────────────────────────────────
const PITCH_INITIAL: float = 1.0
const PITCH_INCREMENT: float = 0.03
const PITCH_MIN: float = 0.8
const PITCH_MAX: float = 2.5
const PITCH_RESET_DELAY: float = 2.0

# ── State ─────────────────────────────────────────────────────────────────────
var _current_pitch: float = PITCH_INITIAL
var _time_since_last_bounce: float = 0.0

# ── Autoload shortcuts ────────────────────────────────────────────────────────
@onready var _event_bus: Node = get_node("/root/EventBus")
@onready var _object_pool: Node = get_node("/root/ObjectPool")

var bounce_stream: AudioStream = null
var brick_stream: AudioStream = null

# ── Lifecycle ─────────────────────────────────────────────────────────────────
func _ready() -> void:
	_try_load_audio()
	_event_bus.ball_bounced.connect(_on_ball_bounced)
	_event_bus.brick_destroyed.connect(_on_brick_destroyed)

func _process(delta: float) -> void:
	# Đếm thời gian không bounce để reset pitch
	_time_since_last_bounce += delta
	if _time_since_last_bounce >= PITCH_RESET_DELAY:
		_current_pitch = PITCH_INITIAL

# ── Signal handlers ───────────────────────────────────────────────────────────

func _on_ball_bounced(_position: Vector2, _normal: Vector2) -> void:
	_time_since_last_bounce = 0.0

	# Tăng pitch
	_current_pitch = clamp(_current_pitch + PITCH_INCREMENT, PITCH_MIN, PITCH_MAX)

	# Phát âm thanh bounce
	_play_sound(bounce_stream, _current_pitch)

func _on_brick_destroyed(_brick_id: int, _world_position: Vector2, _color: Color) -> void:
	# Pitch ngẫu nhiên nhẹ cho tiếng vỡ gạch
	var random_pitch: float = _current_pitch + randf_range(-0.1, 0.1)
	_play_sound(brick_stream, random_pitch)

# ── Private ───────────────────────────────────────────────────────────────────

func _play_sound(stream: AudioStream, pitch: float) -> void:
	if stream == null:
		return
	var player: AudioStreamPlayer = _object_pool.get_audio_player()
	player.stream = stream
	player.pitch_scale = clamp(pitch, PITCH_MIN, PITCH_MAX)
	player.play()

func _try_load_audio() -> void:
	# Load audio nếu file tồn tại
	var bounce_path: String = "res://Assets/Audio/bounce.wav"
	var brick_path: String = "res://Assets/Audio/brick_break.wav"

	if ResourceLoader.exists(bounce_path):
		bounce_stream = load(bounce_path)
	if ResourceLoader.exists(brick_path):
		brick_stream = load(brick_path)
