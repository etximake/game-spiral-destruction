# 🎛 Hướng dẫn chỉnh config — Spiral Destruction

File cấu hình: `../config.json`

> ⚡ **Nguyên tắc vàng**: Chỉ cần sửa JSON, không cần động vào code GDScript.

---

## Mục lục

- [1. Viewport — Khung hình & nền](#1-viewport--khung-hình--nền)
- [2. Spiral — Hình học xoắn ốc](#2-spiral--hình-học-xoắn-ốc)
- [3. Triangles — Tam giác](#3-triangles--tam-giác)
- [4. Ball — Quả bóng](#4-ball--quả-bóng)
- [5. Auto-test — Bộ test tự động](#5-auto-test--bộ-test-tự-động)
- [6. Debris — Mảnh vỡ](#6-debris--mảnh-vỡ)
- [7. Win effect — Hiệu ứng chiến thắng](#7-win-effect--hiệu-ứng-chiến-thắng)
- [8. Audio — Âm thanh](#8-audio--âm-thanh)
- [9. HUD — Giao diện](#9-hud--giao-diện)
- [10. Bảng tra nhanh — Muốn chỉnh X thì sửa đâu?](#10-bảng-tra-nhanh--muốn-chỉnh-x-thì-sửa-đâu)

---

## 1. Viewport — Khung hình & nền

```json
"viewport": {
  "resolution": [1080, 1920],
  "background_color": "#000000",
  "camera_zoom": 0.9
}
```

| Bạn muốn... | Chỉnh |
|---|---|
| Đổi màu nền | `background_color` — hex color, vd: `"#1a1a2e"` (xanh đen), `"#ffffff"` (trắng) |
| Thu nhỏ/phóng to scene | `camera_zoom` — **< 1.0** = thu nhỏ (thấy nhiều hơn), **> 1.0** = phóng to |
| Đổi tỉ lệ khung hình | `resolution` — `[rộng, cao]`. Mặc định 1080×1920 (9:16 dọc) |

---

## 2. Spiral — Hình học xoắn ốc

```json
"spiral": {
  "center": [540.0, 960.0],
  "gap_max": 110.0,
  "gap_min": 35.0,
  "turns": 7.0,
  "points_per_turn": 120,
  "stop_radius": 65.0,
  "line_width": 4.0,
  "line_color": [1.0, 1.0, 1.0, 0.6]
}
```

### `gap_max` / `gap_min` — Khoảng cách giữa các vòng

![gap_max ở ngoài, gap_min ở trong]

- **`gap_max`** (mặc định 110px): Khoảng cách vòng ngoài cùng (miệng spiral). **To hơn** = kênh rộng hơn = bóng dễ vào hơn.
- **`gap_min`** (mặc định 35px): Khoảng cách vòng trong cùng (gần tâm). **Nhỏ hơn** = kênh hẹp hơn = thử thách cao hơn. Nếu `gap_min < 30`, gần như chỉ test thứ 5 (radius 25) mới qua được.

> 💡 **Mẹo**: Giữ `gap_min >= 30` để ball radius 25 (test cuối) có thể lọt qua. Win condition kiểm tra `radius * 2 <= gap_min + 2`.

### `turns` — Số vòng xoắn

- **Nhiều hơn** = đường đi dài hơn = video dài hơn, bóng bounce nhiều hơn.
- **Ít hơn** (vd 4–5) = test nhanh hơn.
- Tác động đến tổng số tam giác được sinh ra.

### `stop_radius` — Vùng an toàn cho emoji

- Spiral **ngừng sinh điểm** khi bán kính < giá trị này. Giữ `stop_radius < 80` để không đè lên vùng emoji.

### `line_width` / `line_color` — Đường viền spiral

- `line_width`: Độ dày. **4–6** = vừa nhìn, **8–12** = dày nổi bật.
- `line_color`: Mảng `[R, G, B, A]` với giá trị **0.0 → 1.0**.
  - Vd `[1.0, 0.5, 0.0, 0.8]` = cam, 80% độ trong suốt.
  - A < 1.0 = đường mờ dần.

### `points_per_turn` — Độ mịn

- **120**: Mượt, đủ cho physics.
- **60**: Giảm nửa số điểm, góc cạnh hơn, physics nhẹ hơn.
- **240**: Rất mượt nhưng tốn bộ nhớ grid hơn.

---

## 3. Triangles — Tam giác

```json
"triangles": {
  "angle_step_deg": 11.25,
  "gap_from_wall": 4.0,
  "collision_ratio": 0.45,
  "min_size": 24.0,
  "max_size": 150.0,
  "size_ratio": 0.95,
  "spacing_ratio": 1.15,
  "color_hue_start": 0.0,
  "color_hue_range": 1.3,
  "skip_at_spawn": 3,
  "skip_at_end": 2,
  "stop_distance_from_center": 80.0,
  "mesh": {
    "outer_brightness": 1.0,
    "inner_brightness": 1.0,
    "inner_alpha": 1.0
  },
  "spawn_animation": {
    "wave_duration": 0.35,
    "scale_up_duration": 0.15
  }
}
```

### Kích thước tam giác

Công thức: `actual_size = clamp(max_possible_size × size_ratio, min_size, max_size)`

| Bạn muốn... | Chỉnh |
|---|---|
| Tam giác to hơn (lấp đầy kênh hơn) | Tăng `size_ratio` (0.95 → 0.98), hoặc giảm `gap_from_wall` (4 → 2) |
| Tam giác nhỏ hơn (dễ nhìn xuyên qua) | Giảm `size_ratio` (0.95 → 0.80), hoặc tăng `gap_from_wall` (4 → 8) |
| Giới hạn kích thước tam giác | `min_size` (tối thiểu) / `max_size` (tối đa) |
| Khoảng cách tối thiểu giữa 2 tam giác | `angle_step_deg` — **lớn hơn** = thưa hơn, **nhỏ hơn** = dày hơn |

### Màu sắc tam giác

- `color_hue_start` (0.0 = đỏ): Màu bắt đầu gradient. Thử `0.6` (xanh dương) hoặc `0.8` (tím).
- `color_hue_range` (1.3): Khoảng hue trải dài từ ngoài vào trong. `2.0` = 2 vòng màu, `0.5` = hẹp.

### Mesh (hình dạng tam giác hiện tại)

Hiện tại tam giác **solid** (fill = border):
- `outer_brightness`: 1.0
- `inner_brightness`: 1.0
- `inner_alpha`: 1.0

> 💡 **Để có hiệu ứng neon cũ**: sửa `outer_brightness=2.5`, `inner_brightness=0.1`, `inner_alpha=0.2`

### Spawn animation

| Field | Default | Ý nghĩa |
|---|---|---|
| `wave_duration` | 0.35 | Tổng thời gian tam giác xuất hiện từng đợt (giây). **Lớn hơn** = xuất hiện chậm, kịch tính. |
| `scale_up_duration` | 0.15 | Thời gian mỗi tam giác scale từ 0→1. **Nhỏ hơn** = bật ra nhanh. |
| `regrow_duration` | 0.5 | Thời gian tam giác bị phá mọc lại từ đường spiral (giây). **Lớn hơn** = mọc chậm, mượt. |

> 💡 **Regrow animation**: Khi chuyển test, chỉ những tam giác đã bị phá mới animate mọc lại (từ tường spiral → vị trí gốc), theo thứ tự từ trong ra ngoài. Tam giác còn sống giữ nguyên.

---

## 4. Ball — Quả bóng

```json
"ball": {
  "initial_radius": 62.0,
  "min_radius": 5.0,
  "base_speed": 900.0,
  "shrink_per_bounce": 1.5,
  "speed_escalation": { "min_multiplier": 1.0, "max_multiplier": 2.2 },
  "trail_length": 20,
  "win_distance": 30.0,
  "color": [1.0, 1.0, 1.0],
  "visual_segments": 16
}
```

| Bạn muốn... | Chỉnh |
|---|---|
| Bóng chạy nhanh hơn | Tăng `base_speed`. Mặc định 900 px/s. |
| Bóng co nhỏ nhanh hơn | Tăng `shrink_per_bounce` (1.5 → 3.0) |
| Bóng co nhỏ chậm hơn | Giảm `shrink_per_bounce` (1.5 → 0.5) |
| Bóng to hơn ngay từ đầu | Tăng `initial_radius` (62 → 80) |
| Bóng nhỏ tối đa | `min_radius` — không co nhỏ dưới giá trị này |
| Tốc độ tăng dần khi vào sâu | `speed_escalation.max_multiplier`: **2.2** = tốc độ ở cuối gấp 2.2 lần ban đầu |
| Trail dài/ngắn hơn | `trail_length` — số điểm trail. 20 = vừa, 40 = dài, 10 = ngắn. |
| Khoảng cách win | `win_distance` — bóng phải cách tâm bao nhiêu px để win. **Nhỏ hơn** = khó hơn. |
| Màu bóng | `color` — mảng `[R, G, B]`. Vd trắng: `[1,1,1]`, đỏ: `[1,0,0]` |

---

## 5. Auto-test — Bộ test tự động

```json
"auto_test": {
  "enabled": true,
  "timeout": 20.0,
  "stuck_no_progress_seconds": 3.0,
  "tests": [
    { "radius": 45.0, "speed": 320.0, "shrink": false },
    ...
  ]
}
```

### Cấu trúc từng test

Mỗi test trong mảng `tests`:

| Field | Ý nghĩa |
|---|---|
| `radius` | Bán kính quả bóng (px) cho test này |
| `speed` | Tốc độ bóng (px/s) |
| `shrink` | `true` = bóng co nhỏ dần khi bounce, `false` = giữ nguyên kích thước |

> 💡 **Mẹo chỉnh test:**
> - **Test 1–4**: Bóng **phải** to hơn `gap_min` để bị kẹt (STUCK). Với `gap_min=35`, radius ≥ 18 là đủ để kẹt (diameter 36 > 35).
> - **Test cuối**: Bóng **phải** nhỏ hơn `gap_min` để lọt qua và WIN.
> - Tăng `speed` ở các test cuối để bóng văng mạnh hơn, vượt qua vòng hẹp.

### Stuck detection

| Field | Ý nghĩa |
|---|---|
| `timeout` | Tối đa **N giây** cho 1 test. Nếu hết giờ → STUCK → chuyển test tiếp. |
| `stuck_no_progress_seconds` | Nếu bóng không tiến gần tâm hơn 5px trong N giây → STUCK. |
| `out_of_bounds_delay` | Chờ N giây rồi mới check out-of-bounds. |
| `out_of_bounds_radius_factor` | Nếu bóng cách tâm > `outer_radius × factor + margin` → out-of-bounds. |

### Transition (hiệu ứng chuyển test)

| Field | Ý nghĩa |
|---|---|
| `flash_duration` | Thời gian mỗi nháy flash (giây). **Lớn hơn** = flash chậm. |
| `flash_count` | Số lần nhấp nháy trước khi chuyển test. |
| `post_delay` | Delay (giây) sau flash trước khi test mới bắt đầu. |

---

## 6. Debris — Mảnh vỡ

```json
"debris": {
  "pool_size": 64,
  "lifetime": 0.8,
  "gravity": 350.0,
  "num_shards": 4,
  "shard_sizes": [30.0, 60.0],
  "launch_speed": [350.0, 900.0],
  "rotation_speed": [-18.0, 18.0],
  "num_burst_particles": 12
}
```

| Bạn muốn... | Chỉnh |
|---|---|
| Mảnh vỡ **to hơn** | Tăng `shard_sizes` — `[min, max]`. Vd `[40, 80]`. |
| Mảnh vỡ **văng xa hơn, mạnh hơn** | Tăng `launch_speed` — `[min, max]`. Vd `[500, 1200]`. |
| Nhiều mảnh hơn/debris | Tăng `num_shards` (4 → 6). |
| Mảnh rơi nhanh hơn | Tăng `gravity` (350 → 600). |
| Mảnh tồn tại lâu hơn | Tăng `lifetime` (0.8 → 1.2). |
| Mảnh xoay nhanh hơn | Tăng `rotation_speed` — `[min, max]`. Giá trị âm = xoay ngược chiều. |
| Hiệu ứng win burst **dày đặc hơn** | Tăng `num_burst_particles` (12 → 20). |

> ⚠️ **Lưu ý**: `pool_size` là số debris tối đa được pre-allocate. Nếu tăng `num_shards` hoặc `num_burst_particles`, không cần tăng `pool_size` trừ khi bạn thấy thiếu.

---

## 7. Win effect — Hiệu ứng chiến thắng

```json
"win_effect": {
  "emoji": "😊",
  "font_size": 80,
  "emoji_size": [160, 160],
  "celebration_emojis": ["😊","🔥","🎉","🌟","👑","🚀","✨","😜","💖","😎","🤤","⚡","💥","🥳"],
  "confetti_colors": [...],
  "total_flood_emojis": 120,
  "center_glow_burst": 8.0
}
```

| Bạn muốn... | Chỉnh |
|---|---|
| Đổi emoji đích | `emoji` — bất kỳ emoji Unicode nào 🎯🏆❤️ |
| Emoji đích to/nhỏ hơn | `font_size` (chữ) / `emoji_size` (khung chứa) |
| Thêm/bớt emoji ăn mừng | `celebration_emojis` — mảng string |
| Confetti nhiều màu hơn | Thêm màu vào `confetti_colors` — mỗi màu là `[R, G, B]` (0→1) |
| Hiệu ứng tràn ngập dày đặc hơn | Tăng `total_flood_emojis` (120 → 200) |
| Center glow bùng nổ hơn | Tăng `center_glow_burst` (8.0 → 15.0) |

---

## 8. Audio — Âm thanh

```json
"audio": {
  "pool_size": 16,
  "pitch_initial": 1.0,
  "pitch_increment": 0.03,
  "pitch_min": 0.8,
  "pitch_max": 2.5,
  "pitch_reset_delay": 2.0,
  "pitch_variation": 0.1,
  "bounce_sound_path": "res://Assets/Audio/bounce.wav",
  "brick_sound_path": "res://Assets/Audio/brick_break.wav"
}
```

| Bạn muốn... | Chỉnh |
|---|---|
| Âm thanh lên cao nhanh hơn | Tăng `pitch_increment` (0.03 → 0.05) |
| Giới hạn cao độ tối đa | `pitch_max` — 2.5 = cao, 4.0 = rất cao chói tai |
| Âm thanh đa dạng hơn | Tăng `pitch_variation` (0.1 → 0.3) — random pitch mỗi lần |
| Reset pitch nhanh hơn | Giảm `pitch_reset_delay` (2.0 → 1.0) |
| Đổi file âm thanh | `bounce_sound_path` / `brick_sound_path` — đường dẫn file `.wav` hoặc `.ogg` |

---

## 9. HUD — Giao diện

```json
"hud": {
  "title": "WILL THE BALLS GET TO CENTER",
  "title_font_size": 42,
  "info_font_size": 28,
  "size_meter": {
    "position": [1030, 200],
    "size": [24, 300],
    "radius_min": 15.0,
    "radius_max": 62.0,
    "border_width": 3
  }
}
```

| Bạn muốn... | Chỉnh |
|---|---|
| Đổi tiêu đề | `title` — string bất kỳ |
| Chữ to/nhỏ hơn | `title_font_size` / `info_font_size` |
| Dịch chuyển size meter | `position` — `[x, y]` |
| Size meter to/nhỏ | `size` — `[rộng, dài]` |
| Khoảng hiển thị size meter | `radius_min` / `radius_max` — tương ứng với kích thước bóng |

---

## 10. Bảng tra nhanh — Muốn chỉnh X thì sửa đâu?

| Hiệu ứng mong muốn | Config key (đường dẫn) |
|---|---|
| 🖤 **Nền tối/sáng hơn** | `viewport.background_color` |
| 🔄 **Spiral rộng/hẹp hơn** | `spiral.gap_max`, `spiral.gap_min` |
| 🔄 **Spiral dài/ngắn hơn** | `spiral.turns` |
| 🔺 **Tam giác to/nhỏ hơn** | `triangles.size_ratio`, `triangles.gap_from_wall` |
| 🔺 **Tam giác dày/thưa** | `triangles.angle_step_deg` |
| 🔺 **Màu tam giác** | `triangles.color_hue_start`, `triangles.color_hue_range` |
| ⚪ **Bóng to/nhỏ** | `ball.initial_radius` |
| ⚪ **Bóng nhanh/chậm** | `ball.base_speed` |
| ⚪ **Bóng co nhỏ nhanh/chậm** | `ball.shrink_per_bounce` |
| ⚪ **Đuôi bóng dài/ngắn** | `ball.trail_length` |
| 🧪 **Độ khó auto-test** | `auto_test.tests[]` (radius, speed) |
| 🧪 **Thời gian chờ test** | `auto_test.timeout`, `auto_test.stuck_no_progress_seconds` |
| 💥 **Mảnh vỡ to/nhỏ** | `debris.shard_sizes` |
| 💥 **Mảnh vỡ văng xa/gần** | `debris.launch_speed` |
| 💥 **Nhiều/ít mảnh vỡ** | `debris.num_shards` |
| 🎉 **Emoji đích** | `win_effect.emoji` |
| 🎉 **Hiệu ứng win dày/thưa** | `win_effect.total_flood_emojis` |
| 🔊 **Âm thanh cao/thấp** | `audio.pitch_increment`, `audio.pitch_max` |
| 📺 **Thu/phóng camera** | `viewport.camera_zoom` |
| 📝 **Tiêu đề HUD** | `hud.title` |

---

> **Mẹo cuối**: Chỉnh 1–2 số mỗi lần, chạy thử, xem kết quả. Config-driven nghĩa là bạn có thể experiment không sợ hỏng code!
