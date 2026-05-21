# 🏗️ KIẾN TRÚC KỸ THUẬT — GODOT CONTENT ENGINE
**Phiên bản:** 1.0  
**Engine:** Godot 4.5 | GDScript | Mobile Renderer 2D

---

## 1. TRIẾT LÝ KIẾN TRÚC

Ba nguyên tắc bất biến:

1. **Zero GC trong runtime** — Không tạo object mới khi simulation đang chạy. Mọi thứ được pre-allocate.
2. **1 Draw Call cho geometry** — Toàn bộ hình học tĩnh render qua `MultiMeshInstance2D`.
3. **Decoupled hoàn toàn** — UI, Logic, Render không biết nhau. Giao tiếp chỉ qua `EventBus`.

---

## 2. CẤU TRÚC THƯ MỤC DỰ ÁN

```
res://
├── Core/
│   ├── Autoloads/
│   │   ├── EventBus.gd          # Singleton: tín hiệu toàn cục
│   │   ├── ObjectPool.gd        # Singleton: tái chế particles/debris
│   │   └── GameManager.gd       # Singleton: state machine, mode registry
│   ├── Base/
│   │   ├── SimulationBase.gd    # Abstract class: interface cho mọi Mode
│   │   └── RenderBase.gd        # Abstract class: interface cho renderer
│   └── GameScene.tscn           # Scene gốc, load Mode động
│
├── Modes/
│   ├── SpiralDestruction/
│   │   ├── SpiralMode.tscn
│   │   ├── SpiralMode.gd
│   │   ├── Systems/
│   │   │   ├── SpiralMapController.gd
│   │   │   └── SpiralRenderController.gd
│   │   └── Entities/
│   │       ├── Ball.tscn
│   │       └── Ball.gd
│   │
│   └── {ModeName}/              # Mỗi mode là một folder độc lập
│       └── ...
│
├── Shared/
│   ├── Effects/
│   │   ├── DebrisParticle.tscn  # Pooled particle prefab
│   │   ├── TrailEffect.gd       # Ball trail renderer
│   │   └── ScreenShake.gd       # Camera shake utility
│   └── Audio/
│       └── AudioManager.gd      # Pitch escalation, SFX pool
│
└── UI/
    ├── HUD.tscn                 # CanvasLayer — không bị ảnh hưởng bởi camera
    └── HUD.gd
```

---

## 3. NODE HIERARCHY — GAME SCENE

```
GameScene (Node2D)
├── Camera2D                     # Có thể shake, zoom — không ảnh hưởng UI
├── CanvasLayer (layer=10)       # HUD luôn trên cùng, cố định
│   └── HUD
├── SimulationContainer (Node2D) # Mode hiện tại được load vào đây
│   └── [Mode Scene]             # Swap động qua GameManager
└── AudioManager (Node)
```

---

## 4. AUTOLOADS (SINGLETONS)

### 4.1. EventBus.gd
Pattern: Observer. Không có logic, chỉ có signals.

```
Signals toàn cục:
├── simulation_started(mode_id: String)
├── simulation_completed(mode_id: String, duration: float)
├── simulation_reset()
│
├── brick_destroyed(brick_id: int, world_position: Vector2, color: Color)
├── ball_bounced(position: Vector2, normal: Vector2)
├── ball_radius_changed(new_radius: float)
│
└── hud_update_requested(key: String, value: Variant)
```

### 4.2. ObjectPool.gd
Pre-allocate tất cả objects khi khởi động. Zero allocation trong runtime.

```
Pool types:
├── debris_particles: Array[GPUParticles2D]  # size: 64
├── trail_points: PackedVector2Array          # pre-allocated buffer
└── audio_players: Array[AudioStreamPlayer]  # size: 16
```

### 4.3. GameManager.gd
State machine + Mode registry.

```
States:
├── IDLE       → Chờ bắt đầu
├── RUNNING    → Simulation đang chạy
├── PAUSED     → Tạm dừng (giữ frame hiện tại)
├── COMPLETED  → Simulation kết thúc, hiện end screen
└── RESETTING  → Reset tức thì, không reload scene

Mode Registry:
└── Dictionary { mode_id: PackedScene }
    Ví dụ: { "spiral": preload("res://Modes/SpiralDestruction/SpiralMode.tscn") }
```

---

## 5. SIMBASE INTERFACE

Mọi Mode phải implement `SimulationBase.gd`:

```gdscript
class_name SimulationBase
extends Node2D

# Gọi khi Mode được load vào SimulationContainer
func setup() -> void: pass

# Gọi để bắt đầu simulation
func start() -> void: pass

# Gọi để reset về trạng thái ban đầu (KHÔNG reload scene)
func reset() -> void: pass

# Gọi khi simulation kết thúc
func on_completed() -> void: pass
```

---

## 6. RENDER PIPELINE

### Chiến lược: 1 Draw Call cho toàn bộ geometry tĩnh

```
MultiMeshInstance2D
├── instance_count = tổng số phần tử (vd: 2000 tam giác)
├── Mỗi instance có:
│   ├── Transform2D  → vị trí, góc xoay, scale
│   └── Color        → màu RGBA (dùng custom_data nếu cần thêm)
│
└── Khi phần tử "vỡ":
    └── set_instance_transform(id, Transform2D.ZERO)
        # Scale về 0 = tàng hình, KHÔNG xóa instance
```

### Spatial Partitioning cho Collision
Vì không dùng Godot Physics cho geometry tĩnh, cần tự quản lý:

```
SpatialGrid (Dictionary):
├── Key: Vector2i(grid_x, grid_y)   # Ô lưới
└── Value: Array[int]                # Danh sách brick_id trong ô đó

Khi kiểm tra va chạm:
1. Tính ô lưới của bóng → lấy 9 ô xung quanh
2. Chỉ kiểm tra brick trong 9 ô đó
3. O(1) thay vì O(n) — critical cho 2000+ bricks
```

---

## 7. BALL PHYSICS (CUSTOM, KHÔNG DÙNG GODOT PHYSICS)

```
Mỗi frame (_physics_process):
1. Lưu old_position = global_position
2. global_position += velocity * delta

CCD (Continuous Collision Detection):
3. Chia đoạn [old_position → new_position] thành N bước nhỏ
4. Tại mỗi bước: kiểm tra va chạm với spatial grid
5. Nếu hit: phản xạ velocity, phát signal, dừng bước đó

Boundary Collision (Spiral Wall):
6. Tính khoảng cách từ bóng đến đường spiral gần nhất
7. Nếu vượt ra ngoài: phản xạ theo normal của đường spiral
8. Giảm ball_radius theo shrink_amount
```

---

## 8. VIEWPORT & CAMERA

```
Project Settings:
├── display/window/size/viewport_width  = 1080
├── display/window/size/viewport_height = 1920
├── display/window/stretch/mode         = canvas_items
└── display/window/stretch/aspect       = keep

Camera2D:
├── Anchor: center màn hình
├── Zoom: điều chỉnh để spiral vừa khung 9:16
└── ScreenShake: offset ngẫu nhiên, decay theo thời gian
```

---

## 9. PERFORMANCE BUDGET

| Hệ thống | Budget |
|---|---|
| Draw calls | ≤ 5 tổng cộng |
| Physics checks/frame | ≤ 50 (spatial grid) |
| Active particles | ≤ 64 (object pool) |
| Memory allocation/frame | 0 bytes (zero GC) |
| Script processing time | ≤ 2ms/frame |

---

## 10. RECORDING SETUP

**Godot Movie Writer** (khuyến nghị):
```
Project Settings → Editor → Movie Writer:
├── movie_file = "output/clip.avi"
├── fps = 60
└── Mix Rate = 44100

Chạy: godot --headless --write-movie output/clip.avi
```

Kết quả: file AVI 60fps, sau đó encode bằng ffmpeg sang MP4 cho Shorts.

```bash
ffmpeg -i output/clip.avi -vcodec libx264 -crf 18 -preset slow output/clip.mp4
```
