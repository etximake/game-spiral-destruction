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

# ── Lifecycle ─────────────────────────────────────────────────────────────────
func _ready() -> void:
	_load_config()
	_try_load_audio()
	_event_bus.ball_bounced.connect(_on_ball_bounced)
	_event_bus.brick_destroyed.connect(_on_brick_destroyed)

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
	var random_pitch: float = _current_pitch + randf_range(-_pitch_variation, _pitch_variation)
	_play_sound(brick_stream, random_pitch)

# ── Private ───────────────────────────────────────────────────────────────────

func _play_sound(stream: AudioStream, pitch: float) -> void:
	if stream == null:
		return
	var player: AudioStreamPlayer = _object_pool.get_audio_player()
	player.stream = stream
	player.pitch_scale = clamp(pitch, _pitch_min, _pitch_max)
	player.play()

func _try_load_audio() -> void:
	# Load audio nếu file tồn tại
	var bounce_path: String = "res://Assets/Audio/bounce.wav"
	var brick_path: String = "res://Assets/Audio/brick_break.wav"

	if ResourceLoader.exists(bounce_path):
		bounce_stream = load(bounce_path)
	if ResourceLoader.exists(brick_path):
		brick_stream = load(brick_path)
