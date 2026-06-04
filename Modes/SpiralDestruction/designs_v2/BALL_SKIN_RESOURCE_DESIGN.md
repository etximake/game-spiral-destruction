# Ball Skin Resource Design

**STATUS:** ✅ DA TRIEN KHAI DAY DU (2026-05-27)

Muc tieu: cho phep thay visual cua ball bang sprite/resource rieng theo config, nhung khong lam thay doi core physics.

---

### ✅ Implementation summary

| Feature | Status | Notes |
|---------|--------|-------|
| `ball.visual` schema (all 6 fields) | ✅ | `type`, `sprite_path`, `scale_to_radius`, `rotation_enabled`, `rotation_speed_multiplier`, `flip_with_velocity`, `fallback_to_mesh` |
| Sprite2D creation in Ball.gd | ✅ | Created once in `_ready()` via `Sprite2D.new()` |
| `_apply_visual_config()` | ✅ | Loads texture, shows/hides mesh/sprite, fallback on error |
| `_update_visual_scale()` | ✅ | Unified: mesh scales by radius/INITIAL_RADIUS, sprite scales by tex_size |
| `scale_to_radius = false` support | ✅ | Sprite keeps natural tex size when false |
| Rotation via `rotation_enabled` | ✅ | `_distance_traveled_for_rotation / radius * multiplier` |
| `flip_with_velocity` | ✅ | `sprite_visual.flip_h = velocity.x > 0.0` |
| `reset()` resets sprite state | ✅ | `_distance_traveled_for_rotation = 0`, `rotation = 0` |
| Trail width = `radius * 2.0` | ✅ | Unchanged |
| Collision unchanged | ✅ | Circle via `radius`, no sprite collision |

---

## 1. Nguyen tac quan trong

Ball co 2 lop rieng:

```text
Physics ball = circle collision: radius, velocity, speed, CCD
Visual ball = mesh circle hoac Sprite2D skin
```

Khong duoc de kich thuoc anh sprite tu quyet dinh collision. Collision luon lay tu `radius`.

---

## 2. Schema config de xuat

Them sub-section `ball.visual`:

```json
"ball": {
  "initial_radius": 45.0,
  "base_speed": 900.0,
  "color": [255, 100, 20],
  "visual": {
    "type": "sprite",
    "sprite_path": "res://Assets/BallSkins/fireball.png",
    "scale_to_radius": true,
    "rotation_enabled": true,
    "rotation_speed_multiplier": 1.0,
    "flip_with_velocity": false,
    "fallback_to_mesh": true
  },
  "glow": {
    "enabled": true,
    "radius_multiplier": 0.9,
    "color": [255, 60, 10],
    "alpha": 0.3
  }
}
```

Fallback neu khong co `ball.visual`:

```json
"visual": {
  "type": "mesh",
  "scale_to_radius": true,
  "rotation_enabled": false,
  "fallback_to_mesh": true
}
```

---

## 3. Asset layout

```text
Assets/
  BallSkins/
    fireball.png
    basketball.png
    soccer_ball.png
    coin.png
    planet.png
    smiley.png
```

Yeu cau asset:

1. PNG nen trong suot.
2. Anh nen gan vuong, vi se scale theo duong kinh ball.
3. Tam vat the nam giua anh.
4. Khong nen dung vat the qua dai trong phase dau vi collision van la circle.

---

## 4. Thay doi trong scene/code

Hien tai `Ball.gd` co:

```gdscript
@onready var visual: MeshInstance2D = $BallVisual
@onready var trail: Line2D = $Trail
@onready var glow: MeshInstance2D = $BallGlow
```

Huong lam an toan:

1. Giu `$BallVisual` lam mesh fallback.
2. Them Sprite2D child trong scene hoac tao mot lan trong `_ready()`:

```text
Ball
  BallVisual      MeshInstance2D
  BallSprite      Sprite2D
  BallGlow        MeshInstance2D
  Trail           Line2D
```

3. Neu sua scene `.tscn`, them `BallSprite` an mac dinh.
4. Neu khong sua scene, trong `_ready()` tao `Sprite2D.new()` mot lan, add child, khong tao lai trong runtime.

Khuyen nghi sua scene de ro rang hon.

---

## 5. API moi trong Ball.gd

Them bien:

```gdscript
@onready var sprite_visual: Sprite2D = get_node_or_null("BallSprite")
var _visual_cfg: Dictionary = {}
var _visual_type: String = "mesh"
var _sprite_rotation_enabled: bool = false
var _sprite_rotation_multiplier: float = 1.0
var _distance_traveled_for_rotation: float = 0.0
```

Trong `set_ball_config()`:

```gdscript
_visual_cfg = _ball_cfg.get("visual", {})
_visual_type = _visual_cfg.get("type", "mesh")
_apply_visual_config()
```

Them function:

```gdscript
func _apply_visual_config() -> void:
    # Load sprite neu type == "sprite".
    # Neu loi, fallback ve mesh.
    # Set visible cho BallVisual/BallSprite.
    # Scale visual theo radius.
```

---

## 6. Scaling rule

Khi `radius` thay doi, ca mesh va sprite phai scale dung.

Hien tai setter `radius` dang scale mesh:

```gdscript
var scale_factor: float = radius / INITIAL_RADIUS
visual.scale = Vector2(scale_factor, scale_factor)
```

Can sua thanh:

```gdscript
_update_visual_scale()
```

Rule:

```gdscript
func _update_visual_scale() -> void:
    if _visual_type == "sprite" and sprite_visual != null and sprite_visual.texture != null:
        var tex_size: Vector2 = sprite_visual.texture.get_size()
        var target_diameter: float = radius * 2.0
        var base_size: float = max(tex_size.x, tex_size.y)
        var s: float = target_diameter / base_size
        sprite_visual.scale = Vector2(s, s)
    elif visual != null:
        var scale_factor: float = radius / INITIAL_RADIUS
        visual.scale = Vector2(scale_factor, scale_factor)
```

---

## 7. Rotation rule

Neu `rotation_enabled = true`, sprite xoay theo quang duong di chuyen:

```gdscript
var distance_this_frame: float = velocity.length() * delta
_distance_traveled_for_rotation += distance_this_frame
sprite_visual.rotation = _distance_traveled_for_rotation / max(radius, 1.0) * _sprite_rotation_multiplier
```

Chi xoay sprite, khong xoay Node `Ball`, vi Trail dang dung global position va physics khong can rotation.

Neu visual la mesh circle, rotation khong quan trong.

---

## 8. Interaction voi auto-test

Auto-test set radius/speed tung run:

```gdscript
ball.set("radius", new_radius)
ball.set("ball_speed", new_speed)
```

Viec nay phai tu dong update sprite scale. Khong can config skin rieng cho tung test trong phase dau.

Neu sau nay can moi test mot skin, them optional:

```json
"auto_test": {
  "tests": [
    { "radius": 45.0, "speed": 800.0, "skin": "basketball" }
  ]
}
```

Khong lam optional nay trong phase dau neu khong can.

---

## 9. Checklist implementation — STATUS 2026-05-27

- [x] Them `BallSprite` vao `Ball.tscn` neu co scene rieng, hoac tao mot lan trong `_ready()`. (Tao dynamic trong `_ready()`)
- [x] Them parser `ball.visual`.
- [x] Neu type la `"mesh"`, hien `BallVisual`, an `BallSprite`.
- [x] Neu type la `"sprite"` va texture load thanh cong, an `BallVisual`, hien `BallSprite`.
- [x] Neu sprite path sai, print warning va fallback mesh.
- [x] Setter `radius` goi `_update_visual_scale()`.
- [x] `_physics_process` chi update sprite rotation neu active va rotation enabled.
- [x] `reset()` reset sprite rotation va distance counter.
- [x] Trail width van bang `radius * 2.0`.
- [x] Glow van scale theo radius/INITIAL_RADIUS nhu cu hoac duoc update neu can. (Glow created with INITIAL_RADIUS, not dynamically resized — as-before behavior)

### Bonus implemented (not in original checklist)

- [x] `flip_with_velocity` config field + `sprite_visual.flip_h` logic.
- [x] `scale_to_radius = false` keeps sprite natural size.
- [x] Unified `_update_visual_scale()` handles both mesh and sprite.

---

## 10. Test cases bat buoc — STATUS

1. ✅ Default config khong co `ball.visual`: ball mesh hien nhu cu. (visual.type = "mesh" default)
2. ⚠️ Config sprite hop le: sprite hien, mesh an. (Can sprite asset)
3. ✅ Config sprite sai path: mesh fallback hien, game khong crash. (push_warning + fallback)
4. ⚠️ Auto-test thay radius: sprite thay doi kich thuoc dung. (Can test visual)
5. ⚠️ Rotation enabled: sprite xoay, collision khong doi. (Can test visual)
6. ⚠️ Ball cham triangle/spiral/win van dung. (Can test visual)

---

## 11. Khong duoc lam — STATUS

- [x] Khong doi `Ball` sang `RigidBody2D`. ✅ (Node2D + custom physics)
- [x] Khong dung sprite alpha/texture de collision. ✅ (collision = circle radius)
- [x] Khong tao Sprite2D moi moi lan reset/test. ✅ (tao 1 lan trong _ready)
- [x] Khong load texture moi frame. ✅ (load 1 lan trong _apply_visual_config)
- [x] Khong de texture path loi lam crash. ✅ (fallback_to_mesh + push_warning)
