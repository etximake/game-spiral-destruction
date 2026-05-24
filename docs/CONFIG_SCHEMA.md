# 📋 CONFIG SCHEMA — Godot Content Engine
**Phiên bản:** 1.0\n**Schema:** `godot-mode-config-schema-v1`

Mỗi Simulation Mode được cấu hình qua 1 file `config.json` trong chính thư mục mode đó.

---

## 1. CẤU TRÚC TỔNG QUAN

```jsonc
{
  "$schema": "godot-mode-config-schema-v1",
  "meta":          { /* Bắt buộc: định danh mode */ },
  "viewport":      { /* Tùy chọn: cấu hình màn hình */ },
  "spiral":        { /* Hình học xoắn ốc */ },
  "triangles":     { /* Hình học tam giác + render */ },
  "ball":          { /* Vật lý bóng */ },
  "auto_test":     { /* Auto-test suite */ },
  "debris":        { /* Hiệu ứng mảnh vỡ */ },
  "win_effect":    { /* Hiệu ứng chiến thắng */ },
  "spatial_grid":  { /* Grid chia không gian */ },
  "audio":         { /* Cấu hình âm thanh */ },
  "hud":           { /* Giao diện HUD */ }
}
```

---

## 2. CHI TIẾT TỪNG SECTION

### 2.1. `meta` — Thông tin mode (BẮT BUỘC)

| Field | Type | Default | Mô tả |
|-------|------|---------|-------|
| `mode_id` | `string` | — | ID duy nhất của mode. Phải khớp key trong `GameManager.MODE_CONFIG_REGISTRY` |
| `name` | `string` | `"Unnamed Mode"` | Tên hiển thị |
| `version` | `string` | `"1.0"` | Phiên bản GDD |
| `description` | `string` | `""` | Mô tả ngắn |
| `scene_path` | `string` | — | Đường dẫn scene (phải bắt đầu bằng `res://`) |

**Ví dụ:**
```json
"meta": {
  "mode_id": "spiral",
  "name": "Spiral Destruction",
  "version": "3.0",
  "description": "Ball bounces through narrowing spiral toward center emoji",
  "scene_path": "res://Modes/SpiralDestruction/SpiralMode.tscn"
}
```

---

### 2.2. `viewport` — Cấu hình màn hình

| Field | Type | Default | Mô tả |
|-------|------|---------|-------|
| `resolution` | `[int, int]` | `[1080, 1920]` | Độ phân giải [width, height] |
| `background_color` | `string` | `"#000000"` | Màu nền (hex) |
| `camera_zoom` | `float` | `1.0` | Zoom camera (ví dụ: 0.9) |

---

### 2.3. `spiral` — Hình học xoắn ốc

| Field | Type | Default | Mô tả |
|-------|------|---------|-------|
| `center` | `[float, float]` | `[540.0, 960.0]` | Tâm xoắn ốc [x, y] |
| `gap_max` | `float` | `110.0` | Khoảng cách vòng ngoài cùng (px) |
| `gap_min` | `float` | `35.0` | Khoảng cách vòng trong cùng (px) |
| `turns` | `float` | `7.0` | Số vòng xoắn |
| `points_per_turn` | `int` | `120` | Điểm/vòng (độ mịn) |
| `stop_radius` | `float` | `65.0` | Bán kính dừng sinh điểm (px từ tâm) |
| `line_width` | `float` | `4.0` | Độ dày đường spiral |
| `line_color` | `[float, float, float, float]` | `[1, 1, 1, 0.6]` | Màu đường RGBA |

---

### 2.4. `triangles` — Hình học & Render tam giác

| Field | Type | Default | Mô tả |
|-------|------|---------|-------|
| `angle_step_deg` | `float` | `11.25` | Góc giữa 2 tam giác (độ) |
| `side` | `float` | `24.0` | Cạnh tam giác đều (px) |
| `gap_from_wall` | `float` | `4.0` | Khoảng cách đến tường spiral |
| `collision_ratio` | `float` | `0.45` | Bán kính collision = size × ratio |
| `min_size` | `float` | `24.0` | Kích thước tối thiểu |
| `max_size` | `float` | `150.0` | Kích thước tối đa |
| `size_ratio` | `float` | `0.95` | % chiều rộng kênh được lấp đầy |
| `spacing_ratio` | `float` | `1.15` | Hệ số spacing động |
| `color_hue_start` | `float` | `0.0` | Hue bắt đầu gradient |
| `color_hue_range` | `float` | `1.3` | Khoảng hue gradient |
| `skip_at_spawn` | `int` | `3` | Số tam giác bỏ qua ở miệng |
| `skip_at_end` | `int` | `2` | Số tam giác bỏ qua ở cuối |
| `stop_distance_from_center` | `float` | `80.0` | Khoảng cách tối thiểu đến tâm |
| `mesh.outer_brightness` | `float` | `2.5` | Độ sáng viền ngoài (HDR) |
| `mesh.inner_brightness` | `float` | `0.1` | Độ sáng ruột |
| `mesh.inner_alpha` | `float` | `0.2` | Alpha ruột |
| `mesh.hollow_scale` | `float` | `0.75` | Scale phần rỗng |
| `spawn_animation.wave_duration` | `float` | `0.35` | Thời gian wave (giây) |
| `spawn_animation.scale_up_duration` | `float` | `0.15` | Thời gian scale up mỗi tam giác |

---

### 2.5. `ball` — Vật lý bóng

| Field | Type | Default | Mô tả |
|-------|------|---------|-------|
| `initial_radius` | `float` | `62.0` | Bán kính ban đầu (px) |
| `min_radius` | `float` | `5.0` | Bán kính tối thiểu khi shrink |
| `base_speed` | `float` | `600.0` | Tốc độ cơ bản (px/s) |
| `shrink_per_bounce` | `float` | `1.5` | Giảm radius mỗi lần nảy (px) |
| `speed_escalation.min_multiplier` | `float` | `1.0` | Hệ số tốc độ tối thiểu |
| `speed_escalation.max_multiplier` | `float` | `2.2` | Hệ số tốc độ tối đa (ở cuối spiral) |
| `trail_length` | `int` | `20` | Số điểm trail |
| `win_distance` | `float` | `30.0` | Khoảng cách đến tâm để win (px) |
| `color` | `[float, float, float]` | `[1, 1, 1]` | Màu bóng RGB |
| `visual_segments` | `int` | `16` | Số segment visual |
| `spawn_offset` | `float` | `20.0` | Offset spawn từ miệng |
| `spawn_target_offset` | `float` | `40.0` | Offset target hướng vào |

---

### 2.6. `auto_test` — Auto-test suite

| Field | Type | Default | Mô tả |
|-------|------|---------|-------|
| `enabled` | `bool` | `true` | Bật/tắt auto-test |
| `timeout` | `float` | `20.0` | Timeout mỗi test (giây) |
| `stuck_no_progress_seconds` | `float` | `3.0` | Số giây không tiến triển → chuyển test |
| `out_of_bounds_delay` | `float` | `1.5` | Delay trước khi check out-of-bounds |
| `out_of_bounds_margin` | `float` | `50.0` | Margin out-of-bounds (px) |
| `out_of_bounds_radius_factor` | `float` | `1.5` | Hệ số bán kính out-of-bounds |
| `transition.flash_duration` | `float` | `0.08` | Thời gian mỗi flash (giây) |
| `transition.flash_count` | `int` | `4` | Số lần flash |
| `transition.post_delay` | `float` | `0.5` | Delay sau transition (giây) |
| `tests` | `array` | — | Danh sách các test con |

**Mỗi test con:**
| Field | Type | Default | Mô tả |
|-------|------|---------|-------|
| `radius` | `float` | — | Bán kính bóng cho test này |
| `speed` | `float` | — | Tốc độ bóng cho test này |
| `shrink` | `bool` | `false` | Cho phép shrink |

---

### 2.7. `debris` — Hiệu ứng mảnh vỡ

| Field | Type | Default | Mô tả |
|-------|------|---------|-------|
| `pool_size` | `int` | `64` | Số object debris pool |
| `lifetime` | `float` | `0.6` | Thời gian sống (giây) |
| `gravity` | `float` | `450.0` | Trọng lực (px/s²) |
| `num_shards` | `int` | `3` | Số mảnh/debris |
| `shard_sizes` | `[float, float]` | `[20, 40]` | Khoảng kích thước mảnh [min, max] |
| `launch_speed` | `[float, float]` | `[160, 480]` | Khoảng tốc độ bắn [min, max] |
| `rotation_speed` | `[float, float]` | `[-12, 12]` | Khoảng tốc độ xoay [min, max] |
| `num_burst_particles` | `int` | `8` | Số particle khi win burst |

---

### 2.8. `win_effect` — Hiệu ứng chiến thắng

| Field | Type | Default | Mô tả |
|-------|------|---------|-------|
| `emoji` | `string` | `"😊"` | Ký tự emoji đích |
| `font_size` | `int` | `80` | Font size emoji |
| `emoji_size` | `[int, int]` | `[160, 160]` | Kích thước label emoji |
| `celebration_emojis` | `[string]` | 14 emojis | Danh sách emoji ăn mừng |
| `confetti_colors` | `[[float]]` | 7 colors | Bảng màu confetti RGB |
| `total_flood_emojis` | `int` | `120` | Tổng số emoji flood |
| `center_glow_burst` | `float` | `8.0` | Cường độ glow burst khi win |

---

### 2.9. `spatial_grid` — Grid chia không gian

| Field | Type | Default | Mô tả |
|-------|------|---------|-------|
| `cell_size` | `float` | `100.0` | Kích thước ô grid (px) |

---

### 2.10. `audio` — Cấu hình âm thanh

| Field | Type | Default | Mô tả |
|-------|------|---------|-------|
| `pool_size` | `int` | `16` | Số audio player pool |
| `pitch_initial` | `float` | `1.0` | Pitch ban đầu |
| `pitch_increment` | `float` | `0.03` | Tăng pitch mỗi lần nảy |
| `pitch_min` | `float` | `0.8` | Pitch tối thiểu |
| `pitch_max` | `float` | `2.5` | Pitch tối đa |
| `pitch_reset_delay` | `float` | `2.0` | Delay reset pitch (giây) |
| `pitch_variation` | `float` | `0.1` | Random pitch variation |
| `bounce_sound_path` | `string` | — | Đường dẫn file bounce sound |
| `brick_sound_path` | `string` | — | Đường dẫn file brick sound |

---

### 2.11. `hud` — Giao diện HUD

| Field | Type | Default | Mô tả |
|-------|------|---------|-------|
| `title` | `string` | — | Tiêu đề HUD |
| `title_font_size` | `int` | `42` | Font size tiêu đề |
| `info_font_size` | `int` | `28` | Font size thông tin |
| `size_meter.position` | `[int, int]` | `[1030, 200]` | Vị trí size meter |
| `size_meter.size` | `[int, int]` | `[24, 300]` | Kích thước size meter |
| `size_meter.radius_min` | `float` | `15.0` | Radius tối thiểu hiển thị |
| `size_meter.radius_max` | `float` | `62.0` | Radius tối đa hiển thị |
| `size_meter.border_width` | `int` | `3` | Độ dày viền |

---

## 3. VALIDATION RULES

`ModeConfigLoader.gd` tự động validate khi load:

| Rule | Mô tả |
|------|-------|
| `meta.mode_id` | Phải là string không rỗng |
| `meta.scene_path` | Phải tồn tại và bắt đầu bằng `res://` |
| `meta.scene_path` tồn tại | `ResourceLoader.exists()` kiểm tra file |
| `auto_test.tests` | Nếu có, không được rỗng |
| Fields thiếu | Tự động merge với DEFAULT_CONFIG |

---

## 4. THÊM MODE MỚI

Xem `docs/HOW_TO_ADD_MODE.md` để biết hướng dẫn từng bước.
