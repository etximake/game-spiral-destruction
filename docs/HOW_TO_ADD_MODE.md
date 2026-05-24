# 🆕 HOW TO ADD A NEW MODE
**Framework:** Godot Content Engine (Config-Driven)
**Engine:** Godot 4.5 | GDScript

Quy trình thêm một Simulation Mode mới vào framework. Mỗi mode là một scene Godot độc lập + 1 file JSON config.

---

## 1. CHECKLIST TỔNG QUAN

```
[ ] Bước 1: Viết GDD
[ ] Bước 2: Tạo folder mode
[ ] Bước 3: Tạo scene Mode
[ ] Bước 4: Code Mode (extends SimulationBase)
[ ] Bước 5: Tạo file JSON config
[ ] Bước 6: Đăng ký vào GameManager
[ ] Bước 7: Test
```

---

## 2. CHI TIẾT TỪNG BƯỚC

### Bước 1: Viết GDD

Copy template tại `docs/TEMPLATE_MODE_GDD.md` → `docs/GDD_{ModeName}.md` và điền thông tin.

Các thông số cần xác định:
- Kích thước viewport (mặc định 1080×1920)
- Thông số hình học (kích thước, khoảng cách, số lượng)
- Thông số vật lý (tốc độ, trọng lực, collision)
- Thông số hiệu ứng (particle, màu sắc, âm thanh)
- Auto-test parameters (nếu có)

---

### Bước 2: Tạo folder mode

```
res://Modes/{ModeName}/
├── {ModeName}Mode.tscn     # Scene chính
├── {ModeName}Mode.gd        # Script (extends SimulationBase)
├── Systems/                 # Hệ thống con (optional)
│   └── ...
└── Entities/                # Thực thể (optional)
    └── ...
```

---

### Bước 3: Tạo scene Mode

1. Tạo scene mới → `Other Node` → chọn `Node2D`
2. Gán script = `{ModeName}Mode.gd`
3. Thêm các node con cần thiết (entities, systems, effects)
4. Lưu scene

**Cấu trúc scene khuyến nghị:**
```
{ModeName}Mode (Node2D) — SimulationBase
├── [MapController] (Node)       — Sinh geometry
├── [RenderController] (Node2D) — MultiMesh rendering
├── [MainEntity] (Node2D)       — Thực thể chính
├── [Camera / CenterGlow]        — Hiệu ứng
└── ...
```

---

### Bước 4: Code Mode

```gdscript
## {ModeName}Mode.gd
extends "res://Core/Base/SimulationBase.gd"

# ── Config shortcuts ────────────────────────────────────────────
var _mode_cfg: Dictionary = {}

func set_config(config: Dictionary) -> void:
    _config = config
    _mode_cfg = config.get("{mode_config_section}", {})
    # Truyền config xuống subsystems nếu cần

# ── SimulationBase interface ─────────────────────────────────────

func setup() -> void:
    # Sinh geometry, pre-compute, init
    pass

func start() -> void:
    # Bắt đầu simulation
    pass

func reset() -> void:
    # Reset state, không reload scene
    pass

func on_completed() -> void:
    # Win effects, emit completed
    pass
```

**Các nguyên tắc:**
- **Zero GC runtime**: Pre-allocate mọi thứ, không tạo object mới khi đang chạy
- **1 Draw Call**: Dùng `MultiMeshInstance2D` cho geometry tĩnh
- **EventBus**: Giao tiếp qua signal, không gọi trực tiếp UI

---

### Bước 5: Tạo file JSON config

Tạo file tại `Modes/{ModeName}/config.json`.

**Cấu trúc tối thiểu:**
```json
{
  "$schema": "godot-mode-config-schema-v1",
  "meta": {
    "mode_id": "your_mode_id",
    "name": "Your Mode Name",
    "version": "1.0",
    "description": "What this mode does",
    "scene_path": "res://Modes/YourMode/YourModeMode.tscn"
  }
}
```

### Bước 6: Đăng ký vào GameManager

Mở `Core/Autoloads/GameManager.gd`, thêm vào `MODE_CONFIG_REGISTRY`:

```gdscript
const MODE_CONFIG_REGISTRY: Dictionary = {
    "spiral":    "res://Modes/SpiralDestruction/config.json",
    "your_mode": "res://Modes/YourMode/config.json",      # ← Thêm dòng này
}
```

Mode ID phải khớp với `meta.mode_id` trong JSON config.

---

### Bước 7: Test

```bash
# Run headless để test compile + auto-test
godot --headless --path . --quit

# Run với editor để test visual
godot --path .
```

**Kiểm tra:**
- [ ] Compile không lỗi
- [ ] Scene load được
- [ ] Simulation chạy đúng
- [ ] Win condition hoạt động
- [ ] Reset không crash
- [ ] 60 FPS ổn định

---

## 3. TEMPLATE NHANH

### Minimal JSON config
```json
{
  "$schema": "godot-mode-config-schema-v1",
  "meta": {
    "mode_id": "my_first_mode",
    "name": "My First Mode",
    "version": "1.0",
    "description": "A simple simulation",
    "scene_path": "res://Modes/MyFirstMode/MyFirstModeMode.tscn"
  }
}
```

### Minimal Mode script
```gdscript
extends "res://Core/Base/SimulationBase.gd"

func set_config(config: Dictionary) -> void:
    _config = config

func setup() -> void:
    print("Mode setup: ", _config.get("meta", {}).get("name", ""))

func start() -> void:
    print("Mode started!")

func reset() -> void:
    print("Mode reset!")

func on_completed() -> void:
    _emit_completed()
```

---

## 4. LƯU Ý QUAN TRỌNG

| Vấn đề | Giải pháp |
|--------|-----------|
| **Không dùng Godot Physics** | Custom physics (CCD) cho entity chính |
| **Không tạo object mới** | ObjectPool cho particles/debris |
| **Hạn chế draw calls** | MultiMeshInstance2D cho geometry lặp lại |
| **UI cố định** | CanvasLayer cho HUD, không bị ảnh hưởng camera |
| **Reset nhanh** | < 0.5s, không reload scene |
| **Config không hợp lệ** | ModeConfigLoader tự động validate, báo lỗi chi tiết |
