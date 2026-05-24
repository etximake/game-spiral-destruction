## ObjectPool.gd
## Singleton — Quản lý tái chế objects để đạt Zero GC trong runtime.
## Tất cả objects được pre-allocate khi _ready(), không tạo mới trong game loop.
extends Node

# ── Pool sizes + arrays (từ config nếu có) ────────────────────────────────────
var _debris_pool_size: int = 64
var _audio_pool_size: int = 16
var _debris_lifetime: float = 0.6

# ── Pool arrays ───────────────────────────────────────────────────────────────
var _debris_pool: Array[Node2D] = []
var _debris_index: int = 0
var _debris_timers: Array[float] = []

var _audio_pool: Array[AudioStreamPlayer] = []
var _audio_index: int = 0

func _ready() -> void:
	# Đọc config từ GameManager nếu có
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.has_method("get_current_config"):
		var cfg: Dictionary = gm.get_current_config()
		var debris_cfg: Dictionary = cfg.get("debris", {})
		var audio_cfg: Dictionary = cfg.get("audio", {})
		_debris_pool_size = debris_cfg.get("pool_size", 64)
		_debris_lifetime = debris_cfg.get("lifetime", 0.6)
		_audio_pool_size = audio_cfg.get("pool_size", 16)
	
	# Pre-allocate debris
	_debris_timers.resize(_debris_pool_size)
	for i: int in _debris_pool_size:
		_debris_timers[i] = 0.0
		var debris: Node2D = _create_debris_node()
		_debris_pool.append(debris)
		add_child(debris)

	# Pre-allocate audio
	for i: int in _audio_pool_size:
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.bus = "Master"  # Dùng Master bus — không cần SFX bus riêng
		_audio_pool.append(player)
		add_child(player)

func _process(delta: float) -> void:
	# Đếm timer cho từng debris slot — Zero GC (không tạo object mới)
	for i: int in _debris_pool_size:
		if _debris_timers[i] > 0.0:
			_debris_timers[i] -= delta
			if _debris_timers[i] <= 0.0:
				_hide_debris_at(i)

# ── Public API ────────────────────────────────────────────────────────────────

func get_debris(world_position: Vector2, color: Color) -> Node2D:
	var idx: int = _debris_index
	_debris_index = (_debris_index + 1) % _debris_pool_size

	var debris: Node2D = _debris_pool[idx]
	debris.global_position = world_position
	_activate_debris(debris, color, idx)
	return debris

func get_audio_player() -> AudioStreamPlayer:
	var player: AudioStreamPlayer = _audio_pool[_audio_index]
	_audio_index = (_audio_index + 1) % _audio_pool_size
	return player

# ── Private ───────────────────────────────────────────────────────────────────

func _create_debris_node() -> Node2D:
	var container: Node2D = Node2D.new()
	container.visible = false
	container.set_script(preload("res://Shared/Effects/GlassDebris.gd"))
	return container

func _activate_debris(debris: Node2D, color: Color, slot_idx: int) -> void:
	debris.visible = true
	if debris.has_method("activate"):
		debris.call("activate", color)
	_debris_timers[slot_idx] = _debris_lifetime

func _hide_debris_at(slot_idx: int) -> void:
	var debris: Node2D = _debris_pool[slot_idx]
	debris.visible = false
	_debris_timers[slot_idx] = 0.0
