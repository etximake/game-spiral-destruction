# 🌀 GDD — MODE: SPIRAL DESTRUCTION
**Mode ID:** `spiral`  
**Phiên bản:** 2.0 (Cập nhật từ ảnh tham chiếu)  
**Framework:** Godot Content Engine (xem `ARCHITECTURE.md`)  
**Thời lượng clip mục tiêu:** 45–75 giây

---

## 1. MÔ TẢ MODE

Một quả bóng trắng nảy bên trong đường xoắn ốc Archimedean. Mỗi lần bóng chạm vào tường xoắn ốc, bóng co nhỏ lại một lượng cố định. Khi bóng đủ nhỏ, nó lọt qua khe hở giữa các vòng xoắn và tiến dần vào tâm — nơi có hiệu ứng glow đặc biệt. Dọc theo đường xoắn ốc là các tam giác màu sắc rực rỡ bị phá hủy khi bóng chạm vào.

**Vòng cảm xúc của clip:**
```
Bóng lớn nảy mạnh phá tam giác ngoài (0-20s)
→ Bóng nhỏ dần, xuyên sâu hơn (20-45s)
→ Bóng rất nhỏ, tiến vào tâm (45-65s)
→ Chạm tâm — hiệu ứng nổ tung thỏa mãn (65-70s)
→ Fade out (70-75s)
```

---

## 2. THÔNG SỐ KỸ THUẬT

### 2.1. Viewport
| Thông số | Giá trị |
|---|---|
| Resolution | 1080 × 1920 (9:16) |
| FPS | 60 |
| Renderer | Godot Mobile 2D |
| Background | Màu đen thuần (#000000) |

### 2.2. Xoắn Ốc (Archimedean Spiral)
| Thông số | Giá trị | Ghi chú |
|---|---|---|
| Công thức | r = a + b × θ | Tọa độ cực |
| `a` (offset tâm) | 30.0 px | Khoảng cách tối thiểu từ tâm |
| `b` (khoảng cách vòng) | 55.0 px | Khoảng cách giữa các vòng |
| Số vòng (turns) | 7 | θ từ 0 đến 7 × 2π |
| Bán kính ngoài cùng | ~415 px | a + b × (7 × 2π) ≈ 415 |
| Điểm bắt đầu spiral | θ = 0, góc 12 giờ (trên cùng) | Đây là khe hở — nơi bóng spawn |
| Tâm spiral | Trung tâm viewport | Vector2(540, 960) |

### 2.3. Tam Giác (Spike/Tooth)
| Thông số | Giá trị | Ghi chú |
|---|---|---|
| Hình dạng | Tam giác cân nhọn | Đỉnh hướng vào tâm |
| Phân bố | Đều theo chu vi mỗi vòng | Số lượng scale theo bán kính |
| Mật độ | ~1 tam giác / 18° | ≈ 20 tam giác/vòng ở vòng trong, ~50 ở vòng ngoài |
| Kích thước | Scale tỉ lệ với bán kính vòng | Vòng ngoài lớn hơn vòng trong |
| Màu sắc | `Color.from_hsv(θ / (2π), 1.0, 1.0)` | Gradient cầu vồng theo góc |
| Render | `MultiMeshInstance2D` | 1 draw call cho tất cả |

### 2.4. Quả Bóng
| Thông số | Giá trị | Ghi chú |
|---|---|---|
| Bán kính ban đầu | 54.0 px | Hiển thị trên HUD |
| Bán kính tối thiểu | 5.0 px | Không co nhỏ hơn |
| Shrink per bounce | 1.5 px | Mỗi lần chạm tường spiral |
| Tốc độ | 420.0 px/s | Không đổi trong toàn bộ simulation |
| Màu | Trắng (#FFFFFF) |  |
| Spawn position | Điểm đầu spiral + offset 80px ra ngoài | Phía trên, cách khe hở |
| Hướng ban đầu | Vector2(0.6, 0.8) normalized | Hướng vào trong spiral |
| Node type | `Node2D` (custom physics) | KHÔNG dùng RigidBody2D |

### 2.5. Tường Spiral (Boundary)
- Tường là chính đường xoắn ốc — bóng nảy khi vượt ra ngoài đường spiral
- Pháp tuyến (normal) tại điểm va chạm = vector vuông góc với tiếp tuyến spiral tại điểm đó
- Khe hở tại θ = 0 (điểm bắt đầu): bóng có thể đi qua, không nảy

---

## 3. GAMEPLAY LOOP

```
[SETUP]
1. Tính toán tất cả điểm spiral → lưu vào PackedVector2Array
2. Sinh tam giác tại mỗi điểm → upload lên MultiMesh
3. Khởi tạo spatial grid cho collision
4. Đặt bóng tại spawn position

[RUNNING - mỗi frame]
5. Di chuyển bóng theo velocity
6. CCD: kiểm tra va chạm với tam giác (spatial grid)
   → Nếu hit: ẩn tam giác, phát debris particle, phát signal
7. Kiểm tra va chạm với tường spiral
   → Nếu hit: phản xạ velocity, giảm ball_radius, phát signal
8. Kiểm tra win condition: bóng đến tâm (distance < 30px)

[WIN]
9. Phát hiệu ứng nổ tâm (burst particles)
10. Phát signal simulation_completed
11. Fade out sau 3 giây
```

---

## 4. WIN CONDITION

- **Win:** `distance(ball.position, spiral_center) < 30.0 px`
- Không có lose condition — simulation luôn kết thúc bằng win
- Nếu bóng co đến `min_radius` (5px) trước khi đến tâm: tiếp tục di chuyển với radius cố định ở 5px

---

## 5. HIỆU ỨNG THỊ GIÁC (JUICE)

### 5.1. Debris Particles
- Trigger: `brick_destroyed` signal
- Lấy từ `ObjectPool` (không tạo mới)
- Màu = màu của tam giác vừa vỡ
- Số hạt: 8–12 per brick
- Lifetime: 0.5s
- Hướng: bắn ra theo normal từ tâm spiral

### 5.2. Ball Trail
- `Line2D` với gradient từ trắng → trong suốt
- Lưu 20 điểm gần nhất của bóng
- Width = ball_radius × 0.5

### 5.3. Screen Shake
- Trigger: bóng chạm tường spiral
- Intensity: `ball_radius / 54.0 × 3.0` px (bóng lớn rung mạnh hơn)
- Decay: 0.15s

### 5.4. Center Glow
- Tại tâm spiral: `PointLight2D` với màu cam/vàng
- Pulse animation: scale sin wave, period 2s
- Khi win: burst to full brightness, fade out

### 5.5. Spiral Wall Visual
- Vẽ đường spiral bằng `Line2D` màu trắng, width 2px
- Opacity: 0.6 (không che khuất tam giác)

### 5.6. Âm Thanh
- Tiếng chạm tường: "Ting" với `pitch_scale` tăng dần
  - Mỗi lần chạm: `pitch_scale += 0.03`
  - Reset về 1.0 sau 2s không chạm
  - Giới hạn: 0.8 → 2.5
- Tiếng vỡ tam giác: click nhẹ, pitch ngẫu nhiên ±0.1
- Win sound: chord âm nhạc thỏa mãn

---

## 6. HUD (THÔNG TIN HIỂN THỊ)

Đặt trong `CanvasLayer` — không bị ảnh hưởng bởi camera shake.

| Thông tin | Vị trí | Format |
|---|---|---|
| Ball radius | Dưới cùng, giữa | `Ball radius: {r:.1f} px` |
| Bricks destroyed | Trên cùng, phải | `{n} / {total}` |
| Timer | Trên cùng, trái | `{mm:ss}` |

Font: Sans-serif trắng, shadow đen nhẹ để đọc được trên mọi nền.

---

## 7. COLLISION SYSTEM CHI TIẾT

### 7.1. Tam Giác — Dùng Circle Approximation
Mỗi tam giác được xấp xỉ bằng một hình tròn (circumscribed circle) để tính va chạm nhanh:
- `collision_radius = triangle_base_width × 0.6`
- Kiểm tra: `distance(ball.pos, triangle.pos) < ball.radius + triangle.collision_radius`

### 7.2. Tường Spiral — Closest Point on Curve
```
1. Lấy segment spiral gần nhất với bóng (từ lookup table pre-computed)
2. Tính closest point trên segment đó
3. Nếu bóng vượt qua segment: phản xạ velocity theo normal
4. Normal = rotate(segment_direction, 90°)
```

### 7.3. CCD (Chống Xuyên Vật Thể)
```
steps = ceil(velocity.length() * delta / ball_radius)
step_delta = delta / steps
for i in steps:
    move one step
    check collisions
    if hit: resolve and break
```

### 7.4. Spatial Grid
- Cell size: `ball_radius_max × 2` = 108px
- Grid bounds: spiral bounding box
- Update: chỉ khi tam giác bị phá (xóa khỏi grid cell)

---

## 8. MILESTONES TRIỂN KHAI

| Milestone | Nội dung | File chính |
|---|---|---|
| **M1** | Core singletons: EventBus, ObjectPool, GameManager | `Core/Autoloads/` |
| **M2** | Sinh toán học spiral + mảng dữ liệu tam giác | `SpiralMapController.gd` |
| **M3** | Render MultiMesh + màu sắc cầu vồng | `SpiralRenderController.gd` |
| **M4** | Ball movement + CCD + spiral wall collision | `Ball.gd` |
| **M5** | Tam giác collision + spatial grid | `SpiralMapController.gd` |
| **M6** | Juice: particles, trail, screen shake, audio | `Shared/Effects/` |
| **M7** | HUD + win condition + reset | `HUD.gd`, `GameManager.gd` |
| **M8** | Polish + recording setup | Project Settings |

---

## 9. CRITICAL GOTCHAS

**G1. Tốc độ bóng không đổi**
Sau khi phản xạ, normalize velocity rồi nhân lại với `BALL_SPEED` cố định. Không để floating point drift làm thay đổi tốc độ.

```gdscript
velocity = velocity.bounce(normal).normalized() * BALL_SPEED
```

**G2. Khe hở spiral**
Tại θ = 0 (điểm bắt đầu/kết thúc spiral), không có tường. Bóng đi qua khe này để vào vòng trong. Logic: chỉ check collision với spiral segment khi segment đó "đóng" (không phải endpoint).

**G3. Reset không reload scene**
Reset chỉ làm:
- `ball.position = spawn_position`, `ball.radius = INITIAL_RADIUS`
- `multimesh.visible_instance_count = total_bricks` (hiện lại tất cả)
- Rebuild spatial grid
- Reset HUD counters

**G4. MultiMesh color channel**
Godot `MultiMesh` hỗ trợ custom color per instance. Dùng `set_instance_color(id, color)` khi setup. Khi brick vỡ: `set_instance_transform(id, Transform2D(0, Vector2.ZERO))` — scale 0 = ẩn.

**G5. Spiral wall normal direction**
Normal phải luôn hướng vào trong (về phía tâm). Kiểm tra: `normal.dot(spiral_center - hit_point) > 0`. Nếu không, flip normal.
