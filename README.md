# Geometric Destruction Sandbox

Godot 4.5 content engine — sản xuất video Shorts 9:16 bằng simulation tự động.

## Mục tiêu

Dùng Godot như **máy quay phim**, không phải game engine. Mỗi mode là một simulation chạy tự động từ đầu đến cuối, tạo ra clip "oddly satisfying" cho YouTube Shorts / TikTok.

## Yêu cầu

- Godot 4.5 stable (Windows)
- Path hiện tại: `D:\Tai lieu kenh algodoo\Godot_v4.5-stable_win64.exe\Godot_v4.5-stable_win64_console.exe`

## Chạy game

1. Mở Godot Editor:
   ```
   Godot_v4.5-stable_win64_console.exe --editor --path "D:\Tai lieu kenh algodoo\game-spiral-destruction"
   ```
2. Nhấn **F5** để chạy.
3. Nhấn **R** để reset simulation.

## Quay video

```bash
Godot_v4.5-stable_win64_console.exe --path "." --write-movie "output/clip.avi"
```

Convert sang MP4:
```bash
ffmpeg -i output/clip.avi -c:v libx264 -crf 18 -preset slow output/clip.mp4
```

## Cấu trúc project

```
Core/
├── Autoloads/          EventBus, ObjectPool, GameManager (singletons)
├── Base/               SimulationBase (interface cho mọi mode)
├── GameScene.tscn      Scene gốc, load mode động
└── GameScene.gd

Modes/
└── SpiralDestruction/  Mode đầu tiên (✅ hoàn thành)
    ├── SpiralMode.gd/tscn
    ├── Systems/        SpiralMapController, SpiralRenderController
    └── Entities/       Ball

Shared/
├── Effects/            ScreenShake
└── Audio/              AudioManager

UI/
└── HUD.gd             FPS, destroyed count, ball radius
```

## Tài liệu thiết kế

| File | Nội dung |
|------|----------|
| `docs/FRAMEWORK_OVERVIEW.md` | Tinh thần cốt lõi, workflow sản xuất, nguyên tắc thiết kế |
| `docs/ARCHITECTURE.md` | Kiến trúc kỹ thuật: autoloads, render pipeline, physics, performance budget |
| `docs/GDD_SpiralDestruction.md` | Spec đầy đủ cho mode Spiral Destruction |
| `docs/TEMPLATE_MODE_GDD.md` | Template để tạo mode mới |

## Nguyên tắc kỹ thuật

- **Zero GC runtime** — không tạo object mới khi simulation chạy
- **1 draw call** — MultiMesh cho toàn bộ geometry tĩnh
- **Decoupled** — mọi giao tiếp qua EventBus (signals)
- **Custom physics** — không dùng RigidBody2D, tự xử lý CCD

## Thêm mode mới

1. Copy `docs/TEMPLATE_MODE_GDD.md`, điền thông số
2. Tạo folder `Modes/{TenMode}/`
3. Implement `SimulationBase` interface (`setup`, `start`, `reset`, `on_completed`)
4. Đăng ký vào `GameManager.MODE_REGISTRY`

## Trạng thái

| Mode | Trạng thái |
|------|-----------|
| Spiral Destruction | ✅ Hoàn thành |
