## DopamineEmojiExplosion.gd (v3 — Dopamine Boost)
## Hiệu ứng chiến thắng gây nghiện:
## 1. Shockwave rings lan từ tâm ra
## 2. Emoji nổ bung từ tâm như pháo hoa
## 3. Sparkle/star particles rơi nhẹ
extends Node2D

# ── Config ────────────────────────────────────────────────────────────────────
var _spiral_center := Vector2(540.0, 960.0)
var _emojis := ["😊", "🔥", "🎉", "🌟", "✨", "💥", "⚡", "🥳"]
var _confetti_colors := [
	Color(1, 0.2, 0.2), Color(0.2, 1, 0.2), Color(0.2, 0.2, 1),
	Color(1, 1, 0.2), Color(1, 0.2, 1), Color(0.2, 1, 1), Color(1, 0.5, 0)
]

func _load_config() -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.has_method("get_current_config"):
		var cfg: Dictionary = gm.get_current_config()
		var we: Dictionary = cfg.get("win_effect", {})
		var sc: Dictionary = cfg.get("spiral", {})
		var center_arr: Array = sc.get("center", [540.0, 960.0])
		_spiral_center = Vector2(center_arr[0], center_arr[1])
		var raw_emojis: Array = we.get("celebration_emojis", [])
		if raw_emojis.size() > 0: _emojis = raw_emojis
		var raw_colors: Array = we.get("confetti_colors", [])
		if raw_colors.size() > 0:
			_confetti_colors.clear()
			for c in raw_colors:
				if c is Array and c.size() >= 3: _confetti_colors.append(Color(c[0], c[1], c[2]))

# ── Data classes ──────────────────────────────────────────────────────────────
class EmojiParticle:
	var label: Label
	var pos: Vector2
	var vel: Vector2
	var rot: float
	var rot_speed: float
	var lifetime: float = 0.0
	var max_lifetime: float

class ShockRing:
	var radius: float = 0.0
	var speed: float = 700.0
	var color: Color
	var width: float = 6.0
	var lifetime: float = 0.0
	var max_lifetime: float = 1.5

class Sparkle:
	var pos: Vector2
	var vel: Vector2
	var color: Color
	var size: float
	var lifetime: float = 0.0
	var max_lifetime: float

# ── State ─────────────────────────────────────────────────────────────────────
var _callback: Callable
var _phase: int = 0
var _phase_timer: float = 0.0
var _emojis_list: Array[EmojiParticle] = []
var _shock_rings: Array[ShockRing] = []
var _sparkles: Array[Sparkle] = []
var _ring_spawned: int = 0

func _ready() -> void:
	z_index = 10
	z_as_relative = false

func play_effect(_spiral_points: PackedVector2Array, callback: Callable) -> void:
	_load_config()
	_callback = callback
	_phase = 1
	_phase_timer = 0.0
	_ring_spawned = 0
	
	# Spawn initial burst: 3 shockwave rings + emoji explosion
	_spawn_emoji_explosion(20)
	_spawn_sparkle_burst(25)
	
	set_process(true)

func _process(delta: float) -> void:
	_phase_timer += delta
	
	# Spawn rings gradually
	if _ring_spawned < 4 and _phase_timer > _ring_spawned * 0.2:
		_spawn_shock_ring()
		_ring_spawned += 1
		if _ring_spawned <= 2:
			_spawn_emoji_explosion(8)
			_spawn_sparkle_burst(10)
	
	# Update physics
	_update_emojis(delta)
	_update_sparkles(delta)
	_update_rings(delta)
	queue_redraw()
	
	# Auto cleanup after 4s
	if _phase_timer > 4.0 and _emojis_list.is_empty() and _sparkles.is_empty() and _shock_rings.is_empty():
		_finish_effect()

# ── Spawning ──────────────────────────────────────────────────────────────────

func _spawn_emoji_explosion(count: int) -> void:
	for i in count:
		var ep := EmojiParticle.new()
		var label := Label.new()
		label.text = _emojis[randi() % _emojis.size()]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var settings := LabelSettings.new()
		settings.font_size = randi_range(32, 64)
		label.label_settings = settings
		label.custom_minimum_size = Vector2(60, 60)
		label.pivot_offset = Vector2(30, 30)
		label.z_index = 8
		label.z_as_relative = false
		add_child(label)
		
		var angle := randf_range(0.0, TAU)
		var speed := randf_range(350.0, 900.0)
		ep.label = label
		ep.pos = _spiral_center
		ep.vel = Vector2(cos(angle), sin(angle)) * speed
		ep.rot = randf_range(0.0, TAU)
		ep.rot_speed = randf_range(-8.0, 8.0)
		ep.max_lifetime = randf_range(2.5, 4.5)
		
		label.position = ep.pos - Vector2(30, 30)
		label.rotation = ep.rot
		label.scale = Vector2.ZERO
		var tween := create_tween()
		tween.tween_property(label, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_BACK)
		
		_emojis_list.append(ep)

func _spawn_shock_ring() -> void:
	var ring := ShockRing.new()
	ring.color = _confetti_colors[randi() % _confetti_colors.size()]
	ring.speed = randf_range(600.0, 900.0)
	ring.width = randf_range(5.0, 12.0)
	_shock_rings.append(ring)

func _spawn_sparkle_burst(count: int) -> void:
	for i in count:
		var sp := Sparkle.new()
		var angle := randf_range(0.0, TAU)
		var speed := randf_range(200.0, 600.0)
		sp.pos = _spiral_center
		sp.vel = Vector2(cos(angle), sin(angle)) * speed
		sp.color = _confetti_colors[randi() % _confetti_colors.size()]
		sp.size = randf_range(3.0, 8.0)
		sp.max_lifetime = randf_range(1.0, 2.5)
		_sparkles.append(sp)

# ── Updates ───────────────────────────────────────────────────────────────────

func _update_emojis(delta: float) -> void:
	var remaining: Array[EmojiParticle] = []
	for ep in _emojis_list:
		ep.lifetime += delta
		if ep.lifetime >= ep.max_lifetime:
			ep.label.queue_free()
			continue
		ep.vel.y += 300.0 * delta
		ep.pos += ep.vel * delta
		ep.rot += ep.rot_speed * delta
		ep.label.position = ep.pos - Vector2(30, 30)
		ep.label.rotation = ep.rot
		var fade_start: float = ep.max_lifetime - 1.0
		if ep.lifetime > fade_start:
			ep.label.modulate.a = clamp((ep.max_lifetime - ep.lifetime) / 1.0, 0.0, 1.0)
		remaining.append(ep)
	_emojis_list = remaining

func _update_sparkles(delta: float) -> void:
	var remaining: Array[Sparkle] = []
	for sp in _sparkles:
		sp.lifetime += delta
		if sp.lifetime >= sp.max_lifetime: continue
		sp.vel.y += 150.0 * delta
		sp.pos += sp.vel * delta
		remaining.append(sp)
	_sparkles = remaining

func _update_rings(delta: float) -> void:
	for ring in _shock_rings:
		ring.lifetime += delta
		ring.radius += ring.speed * delta

# ── Drawing ───────────────────────────────────────────────────────────────────

func _draw() -> void:
	# Draw shockwave rings
	for ring in _shock_rings:
		if ring.lifetime >= ring.max_lifetime: continue
		var alpha := 1.0
		if ring.lifetime > ring.max_lifetime - 0.5:
			alpha = clamp((ring.max_lifetime - ring.lifetime) / 0.5, 0.0, 1.0)
		var c := Color(ring.color.r, ring.color.g, ring.color.b, alpha)
		var glow := Color(ring.color.r, ring.color.g, ring.color.b, alpha * 0.3)
		draw_arc(_spiral_center, ring.radius, 0.0, TAU, 60, glow, ring.width * 3.0, true)
		draw_arc(_spiral_center, ring.radius, 0.0, TAU, 60, c, ring.width, true)
	
	# Draw sparkles as small diamonds
	for sp in _sparkles:
		if sp.lifetime >= sp.max_lifetime: continue
		var alpha := 1.0
		if sp.lifetime > sp.max_lifetime - 0.5:
			alpha = clamp((sp.max_lifetime - sp.lifetime) / 0.5, 0.0, 1.0)
		var c := Color(sp.color.r, sp.color.g, sp.color.b, alpha)
		var s: float = sp.size
		var p: Vector2 = sp.pos
		draw_line(p + Vector2(-s, 0), p + Vector2(0, -s), c, 2.0)
		draw_line(p + Vector2(0, -s), p + Vector2(s, 0), c, 2.0)
		draw_line(p + Vector2(s, 0), p + Vector2(0, s), c, 2.0)
		draw_line(p + Vector2(0, s), p + Vector2(-s, 0), c, 2.0)

func _finish_effect() -> void:
	set_process(false)
	for ep in _emojis_list:
		if is_instance_valid(ep.label): ep.label.queue_free()
	_emojis_list.clear()
	_sparkles.clear()
	_shock_rings.clear()
	if _callback.is_valid(): _callback.call()
	queue_free()
