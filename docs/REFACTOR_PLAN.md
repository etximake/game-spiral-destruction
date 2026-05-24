# 📐 KẾ HOẠCH CẢI TIẾN: JSON CONFIG-DRIVEN MODE SYSTEM
**Phiên bản:** 1.0  
**Mục tiêu:** Mỗi mode được cấu hình qua JSON → Core engine load động

---

## 1. VẤN ĐỀ HIỆN TẠI

```
Mỗi mode: 
  const SPIRAL_GAP_MAX = 110.0    # Hardcode trong code
  const BALL_SPEED = 600.0        # Hardcode trong code
  const TEST_RADII = [...]        # Hardcode trong code

Muốn thay đổi → Phải sửa code → Biên dịch lại → Rủi ro bug
```

Hiện tại có **~50+ tham số** nằm rải rác khắp 14 file, hardcode trong các `const`.

---

## 2. KIẾN TRÚC MỚI

```
Game/
├── configs/
│   ├── spiral_destruction.json   ← Config của mode Spiral
│   └── domino_chain.json         ← Config của mode Domino (tương lai)
│
├── Core/
│   ├── Autoloads/
│   │   ├── EventBus.gd           ← Giữ nguyên
│   │   ├── ObjectPool.gd         ← Lấy config từ JSON
│   │   └── GameManager.gd        ← Load mode scene + config từ JSON
│   ├── Base/
│   │   ├── SimulationBase.gd     ← Giữ nguyên (abstract interface)
│   │   └── ModeConfigLoader.gd   ← MỚI: Parse + validate JSON config
│   └── GameScene.tscn            ← Giữ nguyên
│
├── Modes/
│   ├── SpiralDestruction/
│   │   ├── SpiralMode.gd         ← Đọc config từ JSON thay vì const
│   │   ├── SpiralMode.tscn
│   │   ├── Systems/
│   │   └── Entities/
│   └── ... (mode khác)
│
└── docs/
    ├── ARCHITECTURE.md           ← Cập nhật
    ├── CONFIG_SCHEMA.md           ← MỚI: Schema JSON đầy đủ
    └── HOW_TO_ADD_MODE.md         ← MỚI: Step-by-step thêm mode
```

---

## 3. JSON CONFIG SCHEMA (Ví dụ cho SpiralDestruction)

```jsonc
{
  "$schema": "godot-mode-config-schema-v1",
  "meta": {
    "mode_id": "spiral",
    "name": "Spiral Destruction",
    "version": "3.0",
    "description": "Ball bounces through narrowing spiral toward center emoji",
    "scene_path": "res://Modes/SpiralDestruction/SpiralMode.tscn"
  },

  "viewport": {
    "resolution": [1080, 1920],
    "background_color": "#000000",
    "camera_zoom": 0.9
  },

  "spiral": {
    "center": [540.0, 960.0],
    "gap_max": 110.0,
    "gap_min": 35.0,
    "turns": 7.0,
    "points_per_turn": 120,
    "stop_radius": 65.0,
    "line_width": 4.0,
    "line_color": [1.0, 1.0, 1.0, 0.6]
  },

  "triangles": {
    "angle_step_deg": 11.25,
    "side": 24.0,
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
      "outer_brightness": 2.5,
      "inner_brightness": 0.1,
      "inner_alpha": 0.2,
      "hollow_scale": 0.75
    },
    "spawn_animation": {
      "wave_duration": 0.35,
      "scale_up_duration": 0.15
    }
  },

  "ball": {
    "initial_radius": 62.0,
    "min_radius": 5.0,
    "base_speed": 600.0,
    "shrink_per_bounce": 1.5,
    "speed_escalation": {
      "min_multiplier": 1.0,
      "max_multiplier": 2.2
    },
    "trail_length": 20,
    "win_distance": 30.0,
    "color": [1.0, 1.0, 1.0],
    "visual_segments": 16,
    "spawn_offset": 20.0,
    "spawn_target_offset": 40.0
  },

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
      { "radius": 38.0, "speed": 390.0, "shrink": false },
      { "radius": 25.0, "speed": 470.0, "shrink": false },
      { "radius": 17.0, "speed": 560.0, "shrink": false },
      { "radius": 12.0, "speed": 680.0, "shrink": false }
    ]
  },

  "debris": {
    "pool_size": 64,
    "lifetime": 0.6,
    "gravity": 450.0,
    "num_shards": 3,
    "shard_sizes": [20.0, 40.0],
    "launch_speed": [160.0, 480.0],
    "rotation_speed": [-12.0, 12.0],
    "num_burst_particles": 8
  },

  "win_effect": {
    "emoji": "😊",
    "font_size": 80,
    "emoji_size": [160, 160],
    "celebration_emojis": ["😊","🔥","🎉","🌟","👑","🚀","✨","😜","💖","😎","🤩","⚡","💥","🥳"],
    "confetti_colors": [
      [1.0, 0.2, 0.2], [0.2, 1.0, 0.2], [0.2, 0.2, 1.0],
      [1.0, 1.0, 0.2], [1.0, 0.2, 1.0], [0.2, 1.0, 1.0], [1.0, 0.5, 0.0]
    ],
    "total_flood_emojis": 120,
    "center_glow_burst": 8.0
  },

  "spatial_grid": {
    "cell_size": 100.0
  },

  "audio": {
    "pool_size": 16,
    "pitch_initial": 1.0,
    "pitch_increment": 0.03,
    "pitch_min": 0.8,
    "pitch_max": 2.5,
    "pitch_reset_delay": 2.0,
    "pitch_variation": 0.1,
    "bounce_sound": "res://Assets/Audio/bounce.wav",
    "brick_sound": "res://Assets/Audio/brick_break.wav"
  },

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
}
```

---

## 4. MODECONFIGLOADER.GD — KIẾN TRÚC

```
ModeConfigLoader (Node, không phải Singleton)
├── load_config(path: String) -> Dictionary
│   ├── Parse JSON từ file
│   ├── Validate schema version
│   ├── Validate required fields
│   ├── Set defaults cho optional fields
│   └── Trả về Dictionary hoặc báo lỗi
│
├── get_spiral_config(config: Dictionary) -> SpiralConfig (hoặc Resource)
├── get_ball_config(config: Dictionary) -> BallConfig
├── get_auto_test_config(config: Dictionary) -> AutoTestConfig
│   └── V.v. cho từng subsystem
│
└── Validation rules:
    ├── mode_id phải khớp folder
    ├── scene_path phải tồn tại
    ├── spiral.gap_max > spiral.gap_min
    ├── tests array không được rỗng
    └── Viewport resolution hợp lệ
```

**Luồng dữ liệu:**
```
JSON file → ModeConfigLoader.parse() → Dictionary
    ↓
SpiralMode.setup()
    ↓
SpiralMode lấy config.get("spiral") → truyền vào MapController
SpiralMode lấy config.get("ball") → truyền vào Ball
SpiralMode lấy config.get("auto_test") → cấu hình auto-test
```

---

## 5. LỘ TRÌNH TRIỂN KHAI (5 BƯỚC)

### Bước 1: Tạo Config Schema & Validator
**File mới:** `Core/Base/ModeConfigLoader.gd`

- Định nghĩa JSON schema dạng GDScript Dictionary (required fields, types, defaults)
- `load_config(filepath)` → parse + validate + trả về Dictionary
- `validate_config(data)` → kiểm tra schema, báo lỗi cụ thể

### Bước 2: Tạo config JSON cho SpiralDestruction
**File mới:** `configs/spiral_destruction.json`

- Chuyển tất cả `const` từ code sang JSON
- Giữ schema version để validate

### Bước 3: Refactor SpiralMode + Systems
**Sửa file:** `SpiralMode.gd`, `SpiralMapController.gd`, `SpiralRenderController.gd`, `Ball.gd`

- Thay thế `const SPIRAL_GAP_MAX = 110.0` → `_config.spiral.gap_max`
- ModeConfigLoader tạo instance, load config, truyền xuống subsystems
- Ball nhận config từ parent thay vì const
- RenderController nhận config visual từ JSON

### Bước 4: Refactor GameManager
**Sửa file:** `GameManager.gd`

- MODE_REGISTRY đọc từ JSON meta (`mode_id` → `config_path`)
- Khi start_mode("spiral"):
  1. Đọc `configs/spiral_destruction.json`
  2. Parse + validate
  3. Load scene từ `scene_path`
  4. Truyền config vào mode

### Bước 5: Tài liệu
**File mới:** `docs/CONFIG_SCHEMA.md`, `docs/HOW_TO_ADD_MODE.md`
**Sửa file:** `docs/ARCHITECTURE.md`, `docs/PROMPT_MASTER.md`

- CONFIG_SCHEMA.md: Schema đầy đủ, giải thích từng tham số
- HOW_TO_ADD_MODE.md: Checklist thêm mode mới
- Cập nhật file lỗi thời

---

## 6. LỢI ÍCH

| Khía cạnh | Trước | Sau |
|-----------|-------|-----|
| Thay đổi tham số | Sửa code GDScript | Sửa JSON (không cần biên dịch) |
| Thêm mode mới | Copy code, sửa const | Tạo folder + JSON + scene |
| Người dùng tùy biến | Cần biết GDScript | Cần biết JSON |
| Rủi ro khi edit | Bug compile, syntax error | Validation báo lỗi cụ thể |
| Tái cấu trúc mode | Phải đọc code | Chỉ cần đọc 1 file JSON |
| Chia sẻ config | Gửi code | Gửi file .json |

---

## 7. RỦI RO & GIẢM THIỂU

| Rủi ro | Giải pháp |
|--------|-----------|
| JSON không có type checking | ModeConfigLoader validate type ngay khi parse |
| JSON thiếu field | Có sẵn default values trong loader |
| JSON sai cấu trúc | Schema version check, báo lỗi dòng cụ thể |
| Performance (parse mỗi lần) | Parse 1 lần, cache trong RAM |
| Ball const đã tối ưu (không tạo object) | Config loader tạo struct tĩnh, không ảnh hưởng runtime |

---

## 8. FILE BỊ ẢNH HƯỞNG

### File mới (3 files):
| File | Nội dung |
|------|----------|
| `configs/spiral_destruction.json` | Config của SpiralDestruction mode |
| `Core/Base/ModeConfigLoader.gd` | Parser + Validator cho JSON config |
| `docs/CONFIG_SCHEMA.md` | Tài liệu schema JSON đầy đủ |
| `docs/HOW_TO_ADD_MODE.md` | Hướng dẫn thêm mode mới |

### File sửa (9 files):
| File | Thay đổi |
|------|----------|
| `SpiralMode.gd` | Đọc config từ loader thay vì const |
| `SpiralMapController.gd` | Nhận config spiral từ tham số |
| `SpiralRenderController.gd` | Nhận config visual từ tham số |
| `Ball.gd` | Nhận config ball từ tham số |
| `GameManager.gd` | MODE_REGISTRY + load config |
| `ObjectPool.gd` | Pool sizes từ config |
| `GlassDebris.gd` | Tham số debris từ config |
| `DopamineEmojiExplosion.gd` | Emoji list, physics từ config |
| `AudioManager.gd` | Audio pool, pitch từ config |

---

## 9. PRIORITY & DEPENDENCIES

```
Bước 1: ModeConfigLoader.gd       [Phase 1 - Không phụ thuộc]
  ↓
Bước 2: spiral_destruction.json   [Phase 1 - Phụ thuộc Bước 1]
  ↓
Bước 3: Refactor SpiralMode       [Phase 2 - Phụ thuộc Bước 1,2]
  ↓
Bước 4: Refactor GameManager      [Phase 2 - Phụ thuộc Bước 3]
  ↓
Bước 5: Tài liệu                   [Phase 3 - Phụ thuộc Bước 1-4]
```

Bạn muốn bắt đầu từ bước nào? Tôi đề xuất **Bước 1 → Bước 2** trước.
