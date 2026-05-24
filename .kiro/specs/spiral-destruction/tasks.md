# Tasks — Spiral Destruction Mode

Tất cả tasks đã hoàn thành. Danh sách dưới đây để tham chiếu.

---

## M1 — Core Infrastructure
- [x] Cấu hình project.godot: viewport 1080×1920, Mobile renderer, 3 autoloads
- [x] EventBus.gd — signals toàn cục (Observer pattern)
- [x] ObjectPool.gd — pre-allocate 64 debris + 16 audio players
- [x] GameManager.gd — state machine (IDLE/RUNNING/COMPLETED/RESETTING) + mode registry
- [x] SimulationBase.gd — abstract interface (setup/start/reset/on_completed)
- [x] GameScene.tscn — Camera2D + CanvasLayer(HUD) + SimulationContainer + AudioManager

## M2 — Spiral Math & Data
- [x] Sinh spiral points (Archimedean, 7 vòng, 840 điểm) → PackedVector2Array
- [x] Sinh tam giác: vị trí, góc, scale, màu cầu vồng theo theta
- [x] Spatial grid (cell 108px) → Dictionary[Vector2i, Array[int]]
- [x] Lookup table wall segments cho collision
- [x] get_spiral_wall_info(): normal + closest point + distance

## M3 — Rendering
- [x] MultiMeshInstance2D cho tam giác (1 draw call, ~200 instances)
- [x] Upload transform + color per instance
- [x] Destroy = set transform scale về 0
- [x] Line2D cho spiral wall (trắng, opacity 0.6)
- [x] SpiralMode.tscn với node hierarchy đầy đủ

## M4 — Ball Physics
- [x] Custom physics: velocity + move mỗi frame, tốc độ cố định 420px/s
- [x] CCD: chia frame thành N sub-steps (step = radius × 0.5)
- [x] Spiral wall collision: closest point on segment + reflect + shrink
- [x] Khe hở spiral (5 segment đầu): bóng đi qua, không nảy
- [x] Visual: ArrayMesh hình tròn 16 segments

## M5 — Triangle Collision
- [x] Spatial grid lookup (9 ô xung quanh bóng)
- [x] Circle-circle check: ball.radius + tri.collision_radius
- [x] Emit brick_destroyed signal → SpiralMode xử lý
- [x] Xóa triangle khỏi spatial grid sau khi vỡ

## M6 — Visual Effects & Audio
- [x] Trail: Line2D 20 điểm, gradient trắng→transparent, width = radius×0.5
- [x] Debris: CPUParticles2D pooled (one_shot, 10 hạt, lifetime 0.6s)
- [x] Screen shake: Camera2D offset, intensity theo ball radius, decay 0.15s
- [x] Center glow: PointLight2D pulse (sin wave, period 2s)
- [x] Audio: pitch escalation (+0.03/bounce, reset sau 2s, range 0.8→2.5)
- [x] Win burst: 8 debris particles từ tâm, màu cầu vồng

## M7 — HUD & Game Flow
- [x] HUD: FPS + destroyed count + ball radius (CanvasLayer layer=10)
- [x] Win condition: distance < 30px → trigger on_completed()
- [x] Reset: restore MultiMesh + ball + spatial grid + modulate
- [x] Fade out: tween modulate alpha → 0 trong 1.5s sau win
- [x] Phím R/ESC để reset nhanh

## M8 — Polish
- [x] Parameters tuned cho clip ~60s
- [x] Performance: 3 draw calls, zero GC, spatial grid O(1)
- [x] Reset cycle tức thì (không reload scene)

---

## Lưu ý kỹ thuật

- Không dùng `class_name` trong scripts có reference autoloads (Godot 4.5 parse-time limitation)
- Autoload access pattern: `@onready var _event_bus: Node = get_node("/root/EventBus")`
- GameManager dùng `EventBus` trực tiếp (vì cùng là autoload, load theo thứ tự)
- Headless mode không load autoloads → phải test trong Editor (F5)
