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
- [7. Spatial Grid — Grid không gian](#7-spatial-grid--grid-không-gian-hiệu-suất)
- [8. Win effect — Hiệu ứng chiến thắng](#8-win-effect--hiệu-ứng-chiến-thắng)
- [9. Audio — Âm thanh](#9-audio--âm-thanh)
- [10. HUD — Giao diện](#10-hud--giao-diện)
- [11. Bảng tra nhanh — Muốn chỉnh X thì sửa đâu?](#11-bảng-tra-nhanh--muốn-chỉnh-x-thì-sửa-đâu)

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
  "line_width": 8.0,
  "line_color": [1.0, 1.0, 1.0, 0.6]
}
```

### `gap_max` / `gap_min` — Khoảng cách giữa các vòng

![gap_max ở ngoài, gap_min ở trong]

- **`gap_max`** (mặc định 110px): Khoảng cách vòng ngoài cùng (miệng spiral). **To hơn** = kênh rộng hơn = bóng dễ vào hơn.
- **`gap_min`** (mặc định 35px): Khoảng cách vòng trong cùng (gần tâm). **Nhỏ hơn** = kênh hẹp hơn = thử thách cao hơn. Nếu `gap_min < 30`, gần như chỉ test thứ 5 (radius 25) mới qua được.

> 💡 **Mẹo**: Giữ `gap_min >= 30` để ball radius 25 (test cuối) có thể lọt qua.

### `turns` — Số vòng xoắn

- **Nhiều hơn** = đường đi dài hơn = video dài hơn, bóng bounce nhiều hơn.
- **Ít hơn** (vd 4–5) = test nhanh hơn.
- Tác động đến tổng số tam giác được sinh ra.

### `stop_radius` — Vùng an toàn cho emoji

- Spiral **ngừng sinh điểm** khi bán kính < giá trị này. Giữ `stop_radius < 80` để không đè lên vùng emoji.

### `line_width` / `line_color` — Đường viền spiral

- `line_width`: Độ dày. **6–10** = dày nổi bật, **4–6** = vừa nhìn.
- `line_color`: Mảng `[R, G, B, A]` với giá trị **0.0 → 1.0**.
  - Vd `[1.0, 1.0, 1.0, 0.6]` = trắng, 60% độ trong suốt (mặc định).
  - Hiện tại spiral line dùng **rainbow gradient** từ màu triangles, `line_color` là màu nền dự phòng.

### `points_per_turn` — Độ mịn

- **120**: Mượt, đủ cho physics.
- **60**: Giảm nửa số điểm, góc cạnh hơn, physics nhẹ hơn.
- **240**: Rất mượt nhưng tốn bộ nhớ grid hơn.

---

## 3. Triangles — Tam giác

```json
"triangles": {
  "angle_step_deg": 11.25,
  "side": 24.0,
  "gap_from_wall": 0.0,
  "collision_ratio": 0.45,
  "min_size": 16.0,
  "max_size": 100.0,
  "size_ratio": 0.95,
  "spacing_ratio": 1.15,
  "color_hue_start": 0.8,
  "color_hue_range": 1.0,
  "skip_at_spawn": 3,
  "skip_at_end": 2,
  "stop_distance_from_center": 80.0,
  "mesh": {
    "outer_brightness": 2.5,
    "inner_brightness": 0.15,
    "inner_alpha": 0.3,
    "hollow_scale": 0.7
  },
  "spawn_animation": {
    "wave_duration": 0.35,
    "scale_up_duration": 0.15,
    "regrow_duration": 0.5
  }
}
```

### Kích thước tam giác

Công thức: `actual_size = clamp(max_possible_size × size_ratio, min_size, max_size)`

| Bạn muốn... | Chỉnh |
|---|---|
| Tam giác to hơn (lấp đầy kênh hơn) | Tăng `size_ratio` (0.95 → 0.98), hoặc giảm `gap_from_wall` (0 → -2) |
| Tam giác nhỏ hơn (dễ nhìn xuyên qua) | Giảm `size_ratio` (0.95 → 0.80), hoặc tăng `gap_from_wall` (0 → 4) |
| Giới hạn kích thước tam giác | `min_size` (tối thiểu) / `max_size` (tối đa) |
| Khoảng cách tối thiểu giữa 2 tam giác | `angle_step_deg` — **lớn hơn** = thưa hơn, **nhỏ hơn** = dày hơn |
| Khoảng cách giữa các tam giác dọc spiral | `spacing_ratio` — **> 1.0** = thưa hơn, **< 1.0** = dày hơn |
| Bỏ qua tam giác ở đầu/khu vực spawn | `skip_at_spawn` / `skip_at_end` — số tam giác bỏ qua ở đầu/cuối spiral |

### Màu sắc tam giác

- `color_hue_start` (0.8 = tím/magenta): Màu bắt đầu gradient.
- `color_hue_range` (1.0): Khoảng hue trải dài từ ngoài vào trong — **1.0** = một vòng đầy đủ.

### Mesh — Hiệu ứng Neon Hollow Glow (hình khiên rỗng phát sáng)

Tam giác hiện tại dùng hiệu ứng **viền neon rỗng**:

| Field | Giá trị | Ý nghĩa |
|---|---|---|
| `outer_brightness` | 2.5 | Độ sáng **HDR** của viền ngoài. **> 1.0** = phát sáng neon. |
| `inner_brightness` | 0.15 | Độ tối phần ruột. **Càng thấp** = rỗng càng rõ. |
| `inner_alpha` | 0.3 | Độ trong suốt phần ruột. **< 1.0** = xuyên thấu. |
| `hollow_scale` | 0.7 | Tỉ lệ độ dày viền. **Nhỏ hơn** = viền dày hơn. |

> 💡 **Để có hiệu ứng solid (fill = border) cũ**: sửa `outer_brightness=1.0`, `inner_brightness=1.0`, `inner_alpha=1.0`

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
  "speed_escalation": { "min_multiplier": 1.5, "max_multiplier": 4.0 },
  "trail_length": 30,
  "win_distance": 30.0,
  "color": [255, 100, 20],
  "visual_segments": 16,
  "spawn_offset": 20.0,
  "spawn_target_offset": 40.0,
  "glow": {
    "enabled": true,
    "radius_multiplier": 1.8,
    "color": [255, 60, 10],
    "alpha": 0.3,
    "pulse_speed": 2.0,
    "pulse_amplitude": 0.15
  }
}
```

| Bạn muốn... | Chỉnh |
|---|---|
| Bóng chạy nhanh hơn | Tăng `base_speed`. Mặc định 900 px/s. |
| Bóng co nhỏ nhanh hơn | Tăng `shrink_per_bounce` (1.5 → 3.0) |
| Bóng co nhỏ chậm hơn | Giảm `shrink_per_bounce` (1.5 → 0.5) |
| Bóng to hơn ngay từ đầu | Tăng `initial_radius` (62 → 80) |
| Bóng nhỏ tối đa | `min_radius` — không co nhỏ dưới giá trị này |
| Tốc độ tăng dần khi vào sâu | `speed_escalation`: `min_multiplier` (tỉ lệ đầu), `max_multiplier` (tỉ lệ cuối). **4.0** = tốc độ ở cuối gấp 4 lần ban đầu. |
| Trail dài/ngắn hơn | `trail_length` — số điểm trail. 30 = vừa, 50 = dài, 15 = ngắn. |
| Khoảng cách win | `win_distance` — bóng phải cách tâm bao nhiêu px để win. **Nhỏ hơn** = khó hơn. |
| 🎨 **Màu bóng** | `color` — mảng `[R, G, B]` (0–255). Vd cam lửa: `[255,100,20]`, đỏ: `[255,0,0]` |
| Vị trí spawn | `spawn_offset` / `spawn_target_offset` — offset spawn và target từ miệng spiral |

### 🔥 Glow — Hiệu ứng phát sáng (mới)

Ball hiện tại có halo phát sáng **dạng lửa** (fireball):

| Field | Giá trị | Ý nghĩa |
|---|---|---|
| `enabled` | true | Bật/tắt glow halo |
| `radius_multiplier` | 1.8 | Kích thước halo so với bóng. **Lớn hơn** = halo to hơn. |
| `color` | [255, 60, 10] | Màu halo — đỏ cam phát sáng. |
| `alpha` | 0.3 | Độ mờ halo. **Cao hơn** = rõ hơn, **thấp hơn** = tinh tế hơn. |
| `pulse_speed` | 2.0 | Tốc độ nhấp nháy (Hz). **Cao hơn** = nhấp nháy nhanh hơn. |
| `pulse_amplitude` | 0.15 | Biên độ nhấp nháy. **Cao hơn** = nhấp nháy mạnh hơn. |

> 💡 **Mẹo**: Muốn bóng trông như **quả cầu lửa** 🔥 — giữ nguyên. Muốn **hàn quang** (mát) — đổi `color` thành xanh dương `[0, 150, 255]`. Tắt hẳn: `enabled: false`.

---

## 5. Auto-test — Bộ test tự động

```json
"auto_test": {
  "enabled": true,
  "timeout": 20.0,
  "stuck_no_progress_seconds": 3.0,
  "out_of_bounds_delay": 1.5,
  "out_of_bounds_margin": 50.0,
  "out_of_bounds_radius_factor": 1.5,
  "transition": {
    "flash_duration": 0.08,
    "flash_count": 4,
    "post_delay": 0.5
  },
  "tests": [
    { "radius": 45.0, "speed": 320.0, "shrink": false },
    { "radius": 40.0, "speed": 390.0, "shrink": false },
    { "radius": 35.0, "speed": 470.0, "shrink": false },
    { "radius": 30.0, "speed": 560.0, "shrink": false },
    { "radius": 25.0, "speed": 680.0, "shrink": false }
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

## 7. Spatial Grid — Grid không gian (hiệu suất)

```json
"spatial_grid": {
  "cell_size": 100.0
}
```

Grid chia scene thành các ô vuông để tối ưu collision detection (O(1) thay vì O(n)).

| Bạn muốn... | Chỉnh |
|---|---|
| Tăng độ chính xác collision (tốn CPU hơn) | Giảm `cell_size` (100 → 50) |
| Giảm CPU cho collision (kém chính xác hơn) | Tăng `cell_size` (100 → 150) |

> 💡 **Mặc định 100px** là cân bằng tốt giữa hiệu suất và độ chính xác.

---

## 8. Win effect — Hiệu ứng chiến thắng

```json
"win_effect": {
  "emoji": "😊",
  "font_size": 80,
  "emoji_size": [160, 160],
  "celebration_emojis": ["😊","🔥","🎉","🌟","👑","✨","🚀","😎","🤤","⚡","💥","🥳"],
  "confetti_colors": [...],
  "center_glow_burst": 8.0
}
```

| Bạn muốn... | Chỉnh |
|---|---|
| Đổi emoji đích | `emoji` — bất kỳ emoji Unicode nào 🎯🏆❤️ |
| Emoji đích to/nhỏ hơn | `font_size` (chữ) / `emoji_size` (khung chứa) |
| Thêm/bớt emoji ăn mừng | `celebration_emojis` — mảng string |
| Confetti nhiều màu hơn | Thêm màu vào `confetti_colors` — mỗi màu là `[R, G, B]` (0→1) |
| Center glow bùng nổ hơn | Tăng `center_glow_burst` (8.0 → 15.0) |

---

## 9. Audio — Âm thanh

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

## 10. HUD — Giao diện

```json
"hud": {
  "title": "WILL THE BALLS GET TO CENTER",
  "title_font_size": 64,
  "title_color": "#FF0000",
  "title_outline_color": "#FFFFFF",
  "title_outline_size": 20,
  "info_font_size": 32,
  "size_meter": {
    "position": [1010, 400],
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
| Màu tiêu đề | `title_color` — hex color, vd `"#FF0000"` (đỏ), `"#00FF00"` (xanh) |
| Viền tiêu đề | `title_outline_color` / `title_outline_size` |
| Dịch chuyển size meter | `position` — `[x, y]` |
| Size meter to/nhỏ | `size` — `[rộng, dài]` |
| Khoảng hiển thị size meter | `radius_min` / `radius_max` — tương ứng với kích thước bóng |

---

## 11. Bảng tra nhanh — Muốn chỉnh X thì sửa đâu?

| Hiệu ứng mong muốn | Config key (đường dẫn) |
|---|---|
| 🖤 **Nền tối/sáng hơn** | `viewport.background_color` |
| 🔄 **Spiral rộng/hẹp hơn** | `spiral.gap_max`, `spiral.gap_min` |
| 🔄 **Spiral dài/ngắn hơn** | `spiral.turns` |
| 🔄 **Đường viền spiral** | `spiral.line_width`, `spiral.line_color` |
| 🔺 **Tam giác to/nhỏ hơn** | `triangles.size_ratio`, `triangles.gap_from_wall` |
| 🔺 **Tam giác dày/thưa** | `triangles.angle_step_deg`, `triangles.spacing_ratio` |
| 🔺 **Màu tam giác** | `triangles.color_hue_start`, `triangles.color_hue_range` |
| 🔺 **Độ sáng neon tam giác** | `triangles.mesh.outer_brightness`, `triangles.mesh.inner_alpha` |
| ⚪ **Bóng to/nhỏ** | `ball.initial_radius` |
| ⚪ **Bóng nhanh/chậm** | `ball.base_speed` |
| ⚪ **Bóng co nhỏ nhanh/chậm** | `ball.shrink_per_bounce` |
| ⚪ **Đuôi bóng dài/ngắn** | `ball.trail_length` |
| ⚪ **Màu bóng** | `ball.color` |
| 🔥 **Glow bóng** | `ball.glow.*` (enabled, color, alpha, pulse) |
| 🧪 **Độ khó auto-test** | `auto_test.tests[]` (radius, speed) |
| 🧪 **Thời gian chờ test** | `auto_test.timeout`, `auto_test.stuck_no_progress_seconds` |
| 🧪 **Hiệu ứng chuyển test** | `auto_test.transition.*` (flash_duration, flash_count) |
| 💥 **Mảnh vỡ to/nhỏ** | `debris.shard_sizes` |
| 💥 **Mảnh vỡ văng xa/gần** | `debris.launch_speed` |
| 💥 **Nhiều/ít mảnh vỡ** | `debris.num_shards` |
| 💥 **Burst particles** | `debris.num_burst_particles` |
| 🎉 **Emoji đích** | `win_effect.emoji` |
| 🔊 **Âm thanh cao/thấp** | `audio.pitch_increment`, `audio.pitch_max` |
| 📺 **Thu/phóng camera** | `viewport.camera_zoom` |
| 📝 **Tiêu đề HUD** | `hud.title`, `hud.title_color`, `hud.title_outline_color` |
| 📐 **Collision grid** | `spatial_grid.cell_size` |

---

> **Mẹo cuối**: Chỉnh 1–2 số mỗi lần, chạy thử, xem kết quả. Config-driven nghĩa là bạn có thể experiment không sợ hỏng code!
