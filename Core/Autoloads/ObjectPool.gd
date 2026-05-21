## ObjectPool.gd
## Singleton — Quản lý tái chế objects để đạt Zero GC trong runtime.
## Tất cả objects được pre-allocate khi _ready(), không tạo mới trong game loop.
extends Node

const DEBRIS_POOL_SIZE: int = 64
const AUDIO_POOL_SIZE: int = 16
const DEBRIS_LIFETIME: float = 0.6  # giây

# ── Pool arrays ───────────────────────────────────────────────────────────────
var _debris_pool: Array[Node2D] = []
var _debris_index: int = 0
var _debris_timers: Array[float] = []  # Pre-allocated timer per debris slot

var _audio_pool: Array[AudioStreamPlayer] = []
var _audio_index: int = 0

# ── Lifecycle ─────────────────────────────────────────────────────────────────
func _ready() -> void:
	# Pre-allocate debris
	_debris_timers.resize(DEBRIS_POOL_SIZE)
	for i: int in DEBRIS_POOL_SIZE:
		_debris_timers[i] = 0.0
		var debris: Node2D = _create_debris_node()
		_debris_pool.append(debris)
		add_child(debris)

	# Pre-allocate audio
	for i: int in AUDIO_POOL_SIZE:
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.bus = "Master"  # Dùng Master bus — không cần SFX bus riêng
		_audio_pool.append(player)
		add_child(player)

func _process(delta: float) -> void:
	# Đếm timer cho từng debris slot — Zero GC (không tạo object mới)
	for i: int in DEBRIS_POOL_SIZE:
		if _debris_timers[i] > 0.0:
			_debris_timers[i] -= delta
			if _debris_timers[i] <= 0.0:
				_hide_debris_at(i)

# ── Public API ────────────────────────────────────────────────────────────────

func get_debris(world_position: Vector2, color: Color) -> Node2D:
	var idx: int = _debris_index
	_debris_index = (_debris_index + 1) % DEBRIS_POOL_SIZE

	var debris: Node2D = _debris_pool[idx]
	debris.global_position = world_position
	_activate_debris(debris, color, idx)
	return debris

func get_audio_player() -> AudioStreamPlayer:
	var player: AudioStreamPlayer = _audio_pool[_audio_index]
	_audio_index = (_audio_index + 1) % AUDIO_POOL_SIZE
	return player

# ── Private ───────────────────────────────────────────────────────────────────

func _create_debris_node() -> Node2D:
	var container: Node2D = Node2D.new()
	container.visible = false

	var particles: CPUParticles2D = CPUParticles2D.new()
	particles.emitting = false
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.amount = 10
	particles.lifetime = DEBRIS_LIFETIME - 0.1
	particles.spread = 180.0
	particles.initial_velocity_min = 80.0
	particles.initial_velocity_max = 220.0
	particles.gravity = Vector2(0.0, 200.0)
	particles.scale_amount_min = 0.3
	particles.scale_amount_max = 0.9

	container.add_child(particles)
	return container

func _activate_debris(debris: Node2D, color: Color, slot_idx: int) -> void:
	debris.visible = true
	var particles: CPUParticles2D = debris.get_child(0) as CPUParticles2D
	particles.color = color
	particles.emitting = true
	# Set timer — không tạo object mới
	_debris_timers[slot_idx] = DEBRIS_LIFETIME

func _hide_debris_at(slot_idx: int) -> void:
	var debris: Node2D = _debris_pool[slot_idx]
	debris.visible = false
	var particles: CPUParticles2D = debris.get_child(0) as CPUParticles2D
	particles.emitting = false
	_debris_timers[slot_idx] = 0.0
