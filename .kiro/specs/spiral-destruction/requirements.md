# Requirements — Spiral Destruction Mode

## Tổng quan
Simulation mode cho Godot Content Engine: bóng trắng nảy trong xoắn ốc Archimedean, co nhỏ dần mỗi lần chạm tường, tiến vào tâm. Tự động chạy, không cần input. Output: clip video 9:16 cho Shorts.

## Yêu cầu chức năng

### R1 — Spiral Generation
- Sinh đường xoắn ốc Archimedean với r = a + b×θ (a=30, b=55, 7 vòng)
- Tâm tại Vector2(540, 960), viewport 1080×1920
- Khe hở tại θ=0 (góc 12 giờ) — bóng spawn và đi qua đây

### R2 — Triangle Rendering
- Sinh tam giác dọc theo spiral, mật độ ~1/18°, scale theo bán kính
- Màu gradient cầu vồng theo góc θ
- Render toàn bộ bằng MultiMeshInstance2D (1 draw call)
- Khi vỡ: scale instance về 0, không queue_free

### R3 — Ball Physics (Custom)
- Node2D với custom velocity, tốc độ cố định 420px/s
- CCD: chia frame thành N bước nhỏ, không xuyên vật thể
- Shrink 1.5px mỗi lần chạm tường spiral, min 5px
- Spawn tại điểm đầu spiral + 80px offset, hướng vào trong

### R4 — Collision System
- Spiral wall: closest-point-on-segment, phản xạ theo normal
- Triangle: circle approximation, spatial grid O(1)
- Khe hở tại endpoint spiral không có collision

### R5 — Win Condition
- Win khi distance(ball, center) < 30px
- Không có lose condition

### R6 — Visual Effects
- Debris particles từ ObjectPool khi tam giác vỡ
- Ball trail (Line2D, 20 điểm)
- Screen shake khi chạm tường
- Center glow (PointLight2D, pulse)
- Spiral wall Line2D trắng mờ

### R7 — HUD
- CanvasLayer tách biệt khỏi camera
- Ball radius (dưới giữa), bricks destroyed (trên phải), timer (trên trái)

### R8 — Reset
- Reset tức thì không reload scene
- Restore MultiMesh, reset ball, rebuild spatial grid

## Yêu cầu phi chức năng
- 60 FPS ổn định khi 2000+ tam giác
- Zero GC allocation trong runtime
- Draw calls ≤ 5
