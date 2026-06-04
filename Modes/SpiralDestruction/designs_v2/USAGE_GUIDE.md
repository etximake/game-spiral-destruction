# 🌀 Spiral Destruction — Content Variant Usage Guide

**Phiên bản:** 1.0 | **Ngày:** 2026-05-27

Tài liệu hướng dẫn sử dụng hệ thống content variant cho mode `SpiralDestruction`.

---

## 1. Quick Start

### Chạy với config mặc định

```gdscript
GameManager.start_mode("spiral")
```

Tự động load `Modes/SpiralDestruction/config.json`.

### Chạy với variant

```gdscript
GameManager.start_mode("spiral", "diamond_fireball_square")
GameManager.start_mode("spiral", "pizza_soccer_circle")
GameManager.start_mode("spiral", "heart_coin_triangle")
```

Tự động load từ `Modes/SpiralDestruction/variants/{variant_id}.json`. Nếu file không tồn tại, tự fallback về `config.json` và in cảnh báo.

### 3 variant có sẵn

```text
variants/
├── diamond_fireball_square.json   💎 Fireball sprite + Square obstacles
├── pizza_soccer_circle.json       🍕 Soccer ball sprite + Circle obstacles
└── heart_coin_triangle.json       ❤️ Gold coin sprite + Triangle obstacles
```

---

## 2. Cấu trúc variant file

Mỗi variant là **một file JSON hoàn chỉnh** (full copy của config.json, không phải partial override). Cấu trúc:

```jsonc
{
  "meta":             { /* Tên, mô tả, scene path */ },
  "content":          { /* variant_id, title, target_emoji — PHASE 1 */ },
  "viewport":         { /* Độ phân giải, màu nền */ },
  "spiral":           { /* Hình học xoắn ốc */ },
  "triangles":        { /* Obstacle: shape, fill_style, size, màu */ },
  "ball":             { /* Vật lý + visual (sprite/mesh) */ },
  "auto_test":        { /* 5 ngưỡng test */ },
  "debris":           { /* Hiệu ứng mảnh vỡ */ },
  "win_effect":       { /* Emoji, confetti, ăn mừng */ },
  "recording":        { /* Đường dẫn output video */ },
  "audio":            { /* Âm thanh bounce/fail/win */ },
  "hud":              { /* Font, màu tiêu đề */ },
  "spatial_grid":     { /* Kích thước ô grid */ }
}
```

---

## 3. Tạo variant mới — Step by step

### Bước 1: Copy config mặc định

```powershell
copy Modes\SpiralDestruction\config.json Modes\SpiralDestruction\variants\my_variant.json
```

### Bước 2: Sửa các trường bắt buộc

Mở `my_variant.json`, sửa ít nhất các trường sau:

```jsonc
{
  "content": {
    "variant_id": "my_variant",                    // ← PHẢI khớp tên file
    "title": "CAN THE BALL REACH THE TARGET?",     // ← Hook/quote mới
    "target_emoji": "\uD83C\uDFAF",                // ← Emoji trung tâm
    "description": "My custom variant."
  },
  "triangles": {
    "shape": "square",                             // ← triangle | square | circle | diamond | hexagon
    "fill_style": "wall_attached"                  // ← wall_attached | dense
  },
  "ball": {
    "initial_radius": 50.0,                        // ← Kích thước bóng
    "base_speed": 800.0,                           // ← Tốc độ (px/s)
    "visual": {
      "type": "mesh",                              // ← "mesh" hoặc "sprite"
      "sprite_path": "",                           // ← res://Assets/BallSkins/xxx.png
      "rotation_enabled": false,
      "flip_with_velocity": false
    }
  },
  "auto_test": {
    "tests": [
      { "radius": 38.0, "speed": 850.0 },
      { "radius": 30.0, "speed": 950.0 },
      { "radius": 22.0, "speed": 1050.0 },
      { "radius": 14.0, "speed": 1150.0 },
      { "radius": 8.0,  "speed": 1250.0 }
    ]
  },
  "win_effect": {
    "emoji": "\uD83C\uDFAF"                        // ← Phải khớp content.target_emoji
  },
  "hud": {
    "title": "CAN THE BALL REACH THE TARGET?"     // ← Phải khớp content.title
  },
  "recording": {
    "output_path": "res://recordings/spiral_my_variant.mp4"  // ← Tên file output
  }
}
```

### Bước 3: Test

```gdscript
GameManager.start_mode("spiral", "my_variant")
```

---

## 4. Tham chiếu config — Các field quan trọng

### 4.1. `content` — Định danh variant (PHASE 1)

| Field | Type | Mặc định | Mô tả |
|-------|------|----------|-------|
| `variant_id` | string | `"default"` | ID duy nhất, khớp tên file |
| `title` | string | — | Tiêu đề hiển thị trên HUD và video |
| `target_emoji` | string | `"😊"` | Emoji ở tâm spiral (mục tiêu) |
| `description` | string | `""` | Mô tả ngắn |

> `content.title` ghi đè `hud.title`. `content.target_emoji` ghi đè `win_effect.emoji`.
> Fallback: nếu section `content` bị thiếu → dùng `hud.title` và `win_effect.emoji`.

### 4.2. `triangles` — Obstacle shape & style (PHASE 3)

| Field | Type | Mặc định | Mô tả |
|-------|------|----------|-------|
| `shape` | string | `"triangle"` | Hình dạng obstacle |
| `fill_style` | string | `"wall_attached"` | Cách sắp xếp obstacle |

**`shape` — các giá trị:**

| Giá trị | Mô tả | Visual |
|---------|-------|--------|
| `triangle` | Tam giác nhọn, đỉnh hướng tâm | Neon shield với cung đáy cong |
| `square` | Hình vuông, cạnh = size | Neon hollow box |
| `circle` | Hình tròn, đường kính = size | Neon hollow ring (24 segments) |
| `diamond` | Hình thoi | Neon hollow rhombus |
| `hexagon` | Lục giác đều | Neon hollow hex |

**`fill_style` — các giá trị:**

| Giá trị | Mô tả |
|---------|-------|
| `wall_attached` | 1 obstacle / vị trí, sát thành spiral (mặc định) |
| `dense` | Giảm spacing_ratio để obstacle dày đặc hơn (chỉ cần tune config) |

> `center_lane` và `filled_channel` chưa được triển khai — cần thay đổi logic sinh obstacle.

### 4.3. `ball.visual` — Ball skin (PHASE 2)

| Field | Type | Mặc định | Mô tả |
|-------|------|----------|-------|
| `type` | string | `"mesh"` | `"mesh"` = vòng tròn polygon, `"sprite"` = ảnh PNG |
| `sprite_path` | string | `""` | Đường dẫn PNG (vd: `res://Assets/BallSkins/fireball.png`) |
| `scale_to_radius` | bool | `true` | `true` = scale sprite theo bán kính bóng |
| `rotation_enabled` | bool | `false` | `true` = sprite tự xoay theo quãng đường |
| `rotation_speed_multiplier` | float | `1.0` | Hệ số tốc độ xoay |
| `flip_with_velocity` | bool | `false` | `true` = flip sprite theo hướng di chuyển |
| `fallback_to_mesh` | bool | `true` | `true` = fallback về mesh nếu load sprite lỗi |

**Yêu cầu asset sprite:**

| Thuộc tính | Yêu cầu | Ghi chú |
|------------|---------|---------|
| Định dạng | PNG, nền trong suốt | Bắt buộc — Godot Sprite2D hỗ trợ alpha |
| Kích thước khuyến nghị | **256×256 px** hoặc **512×512 px** | Ảnh vuông, tỉ lệ 1:1 |
| Kích thước tối thiểu | 128×128 px | Dưới mức này sẽ bị mờ khi scale lên cho ball lớn |
| Tâm ảnh | Vật thể nằm chính giữa | Sprite dùng `centered = true` |
| Vùng an toàn | Vật thể chiếm ~80% kích thước ảnh | Để lại margin 10% mỗi cạnh cho glow/smooth edge |

**Tại sao 256×256 hoặc 512×512?**

Bóng có bán kính từ ~5 px (test cuối) đến ~62 px (ban đầu), tương đương đường kính **10–124 px**. Khi `scale_to_radius = true`, sprite được scale từ kích thước gốc xuống `diameter / max(width, height)`. Với ảnh 256×256:

| Ball radius | Đường kính | Scale factor | Pixel hiển thị |
|-------------|-----------|-------------|----------------|
| 62 px (max) | 124 px | 124/256 ≈ 0.48× | ~124 px — sắc nét |
| 45 px | 90 px | 90/256 ≈ 0.35× | ~90 px — sắc nét |
| 25 px | 50 px | 50/256 ≈ 0.20× | ~50 px — đủ rõ |
| 9 px (win) | 18 px | 18/256 ≈ 0.07× | ~18 px — nhỏ nhưng nhận dạng được |

> Dùng 512×512 nếu muốn sắc nét hơn ở ball lớn (62 px radius). 128×128 là tối thiểu — ball sẽ hơi mờ ở kích thước lớn nhất.

**Quy tắc đặt tên asset:**

```text
Assets/BallSkins/
├── fireball.png       # 256×256, lửa/cam
├── basketball.png     # 256×256, bóng rổ
├── soccer_ball.png    # 256×256, bóng đá
├── coin.png           # 256×256, đồng xu vàng
├── planet.png         # 512×512, hành tinh (cần chi tiết hơn)
└── smiley.png         # 256×256, mặt cười
```

**Cách export từ công cụ vẽ (Photoshop/Figma/Aseprite):**

1. Canvas vuông: **256×256 px** hoặc **512×512 px**
2. Vẽ vật thể chiếm ~80% diện tích giữa canvas
3. Xóa background layer → nền trong suốt
4. Export PNG-24 (có alpha channel)
5. Copy vào `res://Assets/BallSkins/`

**Sprite path sai → không crash:**
```
[Ball] Cannot load sprite 'res://Assets/BallSkins/missing.png', falling back to mesh.
```

### 4.4. `auto_test.tests` — 5 ngưỡng test

Mỗi test là 1 object:

```json
{ "radius": 45.0, "speed": 800.0, "shrink": false }
```

| Field | Mô tả |
|-------|-------|
| `radius` | Bán kính bóng cho test này (px) |
| `speed` | Tốc độ bóng (px/s) |
| `shrink` | `true` = bóng co lại khi chạm tường |

> Test cuối cùng phải có `radius` đủ nhỏ để lọt qua vòng trong cùng (gap_min = 35px → radius < 17.5).

### 4.5. `recording` — Output video

```json
{
  "output_path": "res://recordings/spiral_my_variant.mp4"
}
```

Luôn đặt tên file bao gồm `variant_id` để tránh ghi đè.

---

## 5. Bảng tham chiếu nhanh — Shape

| Shape | `collision_ratio` gợi ý | `size_ratio` gợi ý | `hue_start` gợi ý |
|-------|--------------------------|---------------------|--------------------|
| triangle | 0.25–0.45 | 0.8 | 0.0 (đỏ) hoặc 0.8 (tím) |
| square | 0.45–0.60 | 0.7 | 0.3 (xanh lá) |
| circle | 0.50 | 0.6 | 0.6 (xanh dương) |
| diamond | 0.35–0.50 | 0.75 | 0.15 (cam) |
| hexagon | 0.40–0.55 | 0.7 | 0.1 (vàng) |

---

## 6. Troubleshooting

| Vấn đề | Nguyên nhân | Cách sửa |
|--------|-------------|----------|
| Game không load variant | Sai tên variant_id hoặc file không tồn tại | Kiểm tra `variants/{variant_id}.json` tồn tại, variant_id khớp |
| Sprite không hiện | Đường dẫn sai hoặc ảnh không load được | Kiểm tra `res://` path, đảm bảo PNG đã import |
| Tiêu đề HUD không đổi | `content.title` không được set | Đảm bảo section `content` có `title` trong file variant |
| Emoji trung tâm sai | `content.target_emoji` không được set | Đảm bảo `content.target_emoji` và `win_effect.emoji` giống nhau |
| Obstacle sai shape | `triangles.shape` sai giá trị | Chỉ dùng: `triangle`, `square`, `circle`, `diamond`, `hexagon` |
| Ball không tới được tâm | `auto_test.tests[4].radius` quá lớn | Radius test cuối phải < 17.5 px với gap_min = 35 |
| Video output bị ghi đè | `recording.output_path` trùng tên | Đặt tên chứa variant_id: `spiral_{variant_id}.mp4` |
| Fallback về mesh dù có sprite | `fallback_to_mesh: false` + path sai | Đổi `fallback_to_mesh: true` hoặc sửa path |

---

## 7. Checklist tạo variant mới

- [ ] Copy `config.json` → `variants/{variant_id}.json`
- [ ] Sửa `content.variant_id` = tên file
- [ ] Sửa `content.title` = hook mới
- [ ] Sửa `content.target_emoji` = emoji mới
- [ ] Sửa `win_effect.emoji` = khớp `content.target_emoji`
- [ ] Sửa `hud.title` = khớp `content.title`
- [ ] Sửa `triangles.shape` = chọn shape
- [ ] Sửa `ball.initial_radius` + `ball.base_speed` phù hợp
- [ ] Sửa `ball.visual` nếu muốn sprite
- [ ] Sửa `auto_test.tests` — 5 ngưỡng radius giảm dần
- [ ] Sửa `recording.output_path` = chứa variant_id
- [ ] Test: `GameManager.start_mode("spiral", "{variant_id}")`
- [ ] Test fallback: xóa file variant, chạy lại → phải load default config

---

## 8. Related Documents

| Tài liệu | Mô tả |
|----------|-------|
| `DEEPSEEK_IMPLEMENTATION_CHECKLIST.md` | Checklist triển khai (đã hoàn thành) |
| `CONTENT_VARIANTS_PLAN.md` | Kế hoạch thiết kế content variant |
| `BALL_SKIN_RESOURCE_DESIGN.md` | Thiết kế ball sprite skin |
| `OBSTACLE_SHAPE_VARIANTS_DESIGN.md` | Thiết kế obstacle shapes |
| `../../docs/ARCHITECTURE.md` | Kiến trúc tổng thể Godot Content Engine |
| `../../docs/CONFIG_SCHEMA.md` | Schema config đầy đủ |
| `../designs/GDD_SpiralDestruction.md` | Game design document |

---

## 9. Ví dụ: Tạo variant "🏆 trophy_basketball_square"

```powershell
copy Modes\SpiralDestruction\config.json Modes\SpiralDestruction\variants\trophy_basketball_square.json
```

Sửa các trường:

```json
{
  "content": {
    "variant_id": "trophy_basketball_square",
    "title": "WHICH BALL WINS THE TROPHY?",
    "target_emoji": "\uD83C\uDFC6"
  },
  "triangles": { "shape": "square" },
  "ball": {
    "initial_radius": 48.0,
    "base_speed": 750.0,
    "visual": {
      "type": "sprite",
      "sprite_path": "res://Assets/BallSkins/basketball.png",
      "rotation_enabled": true
    }
  },
  "auto_test": {
    "tests": [
      { "radius": 38, "speed": 800 },
      { "radius": 30, "speed": 880 },
      { "radius": 22, "speed": 970 },
      { "radius": 15, "speed": 1080 },
      { "radius": 9,  "speed": 1200 }
    ]
  },
  "win_effect": { "emoji": "\uD83C\uDFC6" },
  "hud": { "title": "WHICH BALL WINS THE TROPHY?" },
  "recording": { "output_path": "res://recordings/spiral_trophy_basketball_square.mp4" }
}
```

Chạy:

```gdscript
GameManager.start_mode("spiral", "trophy_basketball_square")
```
