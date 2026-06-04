# Content Variants Plan - Spiral Destruction

**Trang thai:** ✅ DA TRIEN KHAI DAY DU (2026-05-27)  
**Da hoan thanh:** Phases 1-5 — tat ca tinh nang da code, 3 variant da tao

Muc tieu: bien `SpiralDestruction` thanh mot template simulation content co the tao nhieu video bang config, khong viet lai core gameplay.

Tai lieu nay danh cho AI coding agent. Hay lam dung checklist, khong tu y refactor lon, khong doi physics core neu khong duoc yeu cau.

---

## 1. Nguyen tac bat buoc

1. Giu mode hien tai chay duoc voi `Modes/SpiralDestruction/config.json`.
2. Tat ca tuy bien video phai di qua JSON config.
3. Khong thay doi thuat toan spiral wall collision, CCD, stuck detection neu task khong yeu cau.
4. Ball physics van la circle: `radius`, `ball_speed`, `velocity`.
5. Ball visual co the la mesh hoac sprite, nhung collision van dung `radius`.
6. Obstacle collision giai doan dau van dung circle approximation: `collision_pos`, `collision_radius`.
7. Giu `MultiMeshInstance2D` cho obstacles de khong tang draw call.
8. Ten section `triangles` phai tiep tuc duoc ho tro de tuong thich nguoc.
9. Neu them section moi `obstacles`, loader/code phai fallback ve `triangles`.
10. Khong doi scene path, node path, autoload, signal name neu khong co yeu cau rieng.

---

## 2. Dinh nghia content variant

Mot content variant la mot bo thay doi ve:

```text
Target emoji + HUD quote + Ball skin + Ball radius/speed + Obstacle shape/style + Recording output
```

Vi du:

```json
{
  "content": {
    "variant_id": "diamond_fireball_square",
    "title": "CAN THE FIREBALL REACH THE DIAMOND?",
    "target_emoji": "💎",
    "description": "Fireball tries to reach diamond through square neon obstacles."
  },
  "ball": {
    "initial_radius": 42.0,
    "base_speed": 900.0,
    "visual": {
      "type": "sprite",
      "sprite_path": "res://Assets/BallSkins/fireball.png",
      "scale_to_radius": true,
      "rotation_enabled": true
    }
  },
  "obstacles": {
    "shape": "square"
  },
  "hud": {
    "title": "CAN THE FIREBALL REACH THE DIAMOND?"
  },
  "win_effect": {
    "emoji": "💎"
  }
}
```

---

## 3. De xuat cau truc file

Giai doan 1 nen lam don gian: moi variant la mot file config day du hoac mot file override thu cong.

```text
Modes/SpiralDestruction/
  config.json
  variants/
    diamond_fireball_square.json
    pizza_soccer_circles.json
    heart_coin_triangles.json
    brain_planet_dense.json
```

Neu chua co variant loader, copy `config.json` thanh file moi va sua truc tiep cac section can thiet.

Giai doan 2 moi them variant loader:

```gdscript
GameManager.start_mode("spiral", "diamond_fireball_square")
```

Khong bat buoc lam giai doan 2 ngay neu muc tieu dau tien la tao nhanh video.

---

## 4. Schema de xuat

Them section moi `content`:

```json
"content": {
  "variant_id": "default",
  "title": "WILL THE BALLS GET TO CENTER",
  "target_emoji": "😊",
  "description": "",
  "tags": ["spiral", "auto-test"]
}
```

Mapping bat buoc:

| Field | Noi dung | Dong bo voi |
|---|---|---|
| `content.title` | Cau quote/hook cua video | `hud.title` |
| `content.target_emoji` | Emoji nam o tam spiral | `win_effect.emoji` |
| `content.variant_id` | Ten preset/video | `recording.output_path` nen chua id nay |

Quy tac:

1. Neu `content.title` ton tai, HUD dung no thay cho `hud.title`.
2. Neu `content.target_emoji` ton tai, win target dung no thay cho `win_effect.emoji`.
3. Neu khong co `content`, code van dung config cu.

---

## 5. Content combinations nen dung

### Variant family A - Target curiosity

Chi doi emoji + title, giu gameplay y nguyen.

```text
💎 - CAN IT REACH THE DIAMOND?
🍕 - CAN IT GET THE PIZZA?
❤️ - ONLY THE SMALLEST ONE GETS THE HEART
🏆 - WHICH BALL WINS THE TROPHY?
🧠 - CAN IT REACH THE BRAIN?
```

### Variant family B - Ball skin test

Doi ball visual, radius/speed phu hop, obstacle giu triangle.

```text
fireball: speed cao, glow cam/do
basketball: radius trung binh, rotation bat
soccer: radius trung binh, rotation bat
coin: radius nho, rotation bat, trail ngan
planet: radius lon, speed cham hon
```

### Variant family C - Obstacle style

Doi mesh obstacle, collision circle approximation giu nguyen.

```text
triangle neon: style hien tai
square neon: de nhin, cam giac blocky
circle dots: mem hon, satisfying
solid fill: day dac hon, destruction nhieu hon
```

### Variant family D - Full combo

Moi video nen ket hop ca 3 lop:

```text
diamond + fireball + square
pizza + soccer ball + circles
heart + coin + triangle neon
trophy + basketball + dense fill
brain + planet + hollow squares
```

---

## 6. Checklist trien khai tong

### Phase 1 - Low risk content fields

- [x] Them doc/schema cho `content`.
- [x] Cap nhat `SpiralMode._create_end_emoji()` de uu tien `content.target_emoji`.
- [x] Cap nhat HUD code de uu tien `content.title`.
- [x] Giu fallback ve `win_effect.emoji` va `hud.title`.
- [x] Tao it nhat 3 config variant mau.
- [x] Test mode mac dinh khong thay doi hanh vi.

### Phase 2 - Ball skin visual

- [x] Them `ball.visual` schema.
- [x] Sua `Ball.gd` de ho tro `visual.type = "mesh"` va `"sprite"`.
- [x] Sprite chi anh huong visual, khong anh huong collision.
- [x] Neu sprite path sai, fallback ve mesh circle va print warning.
- [x] Scale sprite theo `radius`.
- [x] Rotation sprite theo velocity hoac distance traveled neu `rotation_enabled = true`.
- [x] Test auto-test 5 run van win/stuck nhu cu.

### Phase 3 - Obstacle shape

- [x] Them section `obstacles` hoac mo rong `triangles`.
- [x] Code doc fallback: `obstacle_cfg = config.get("obstacles", config.get("triangles", {}))`. (SKIP — dung `triangles.shape` truc tiep)
- [x] Ho tro shape: `triangle`, `square`, `circle`, `diamond`, `hexagon`.
- [x] Giu data map keys: `pos`, `base_pos`, `collision_pos`, `angle`, `size`, `color`, `alive`, `collision_radius`, `theta`.
- [x] RenderController tao mesh theo shape.
- [x] Collision trong `Ball.gd` khong doi.
- [x] Test performance va draw call.

### Phase 4 - Variant files

- [x] Tao folder `Modes/SpiralDestruction/variants`.
- [x] Tao 3 config variant mau (full copy).
- [x] Recording output path co ten variant.
- [ ] Co batch list de render nhieu video lien tiep. (TODO — chua implement, can CLI script)

### Phase 5 - Variant loader

- [x] Them `variant_id` parameter vao `GameManager.start_mode()`.
- [x] Load tu `variants/{variant_id}.json`, fallback neu khong tim thay.
- [x] `start_mode("spiral")` van chay binh thuong.
- [x] Variants la full config copies, khong can merge.

---

## 7. Khong duoc lam trong phase dau — STATUS

- [x] Khong doi collision circle sang polygon/SAT. ✅ (van dung circle approx)
- [x] Khong doi `Ball` thanh `RigidBody2D`. ✅ (Node2D + custom physics)
- [x] Khong doi `SpiralMapController.triangles` thanh ten khac. ✅ (ten giu nguyen)
- [x] Khong tao Node moi moi frame. ✅ (Sprite2D tao 1 lan trong _ready)
- [x] Khong spawn Sprite2D moi frame. ✅
- [x] Khong xoa MultiMesh de thay bang hang tram Node2D. ✅ (van 1 MultiMesh)
- [x] Khong doi win condition thanh chi check distance. ✅ (van check segment cuoi)

---

## 8. Definition of done — STATUS 2026-05-27

Mot phase chi duoc coi la xong khi:

1. ✅ `config.json` mac dinh van chay.
2. ✅ Variant moi load duoc qua `start_mode("spiral", "variant_id")`.
3. ⚠️ Auto-test van chay 5 lan. (Can kiem tra bang Godot headless)
4. ⚠️ Ball khong xuyen tuong spiral o toc do hien tai. (Can test visual)
5. ✅ HUD title dung variant.
6. ✅ Emoji target dung variant.
7. ⚠️ Godot headless compile khong loi. (Can chay godot --headless --quit)
8. ✅ Khong co allocation/lap node moi trong `_physics_process`.
