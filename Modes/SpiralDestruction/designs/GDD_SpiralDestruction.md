# 🌀 GDD — MODE: SPIRAL DESTRUCTION
**Mode ID:** `spiral`  
**Phiên bản:** 3.0  
**Framework:** Godot Content Engine (xem `../../docs/ARCHITECTURE.md`)  
**Thời lượng clip mục tiêu:** 45–75 giây

---

## 1. MÔ TẢ MODE

Một quả bóng trắng di chuyển từ **ngoài vào trong** theo đường xoắn ốc dạng vỏ ốc 2D. Đường xoắn ốc thu hẹp dần về tâm. Ball phải đủ nhỏ để lọt qua các vòng hẹp bên trong. Ở tâm spiral có emoji 😊 — ball chạm emoji = WIN.

Simulation chạy **5 lần liên tiếp** (auto-test), mỗi lần ball có kích thước nhỏ hơn, đi sâu hơn vào spiral. Lần cuối ball đủ nhỏ để đến tâm và chạm emoji.

**Vòng cảm xúc của clip:**
```
Lần 1: Ball lớn, đi được 1/10 đường → bị kẹt (0-10s)
Lần 2: Ball nhỏ hơn, đi được 3/10 đường → bị kẹt (10-22s)
Lần 3: Ball nhỏ hơn nữa, đi được 5/10 đường → bị kẹt (22-36s)
Lần 4: Ball nhỏ, đi được 8/10 đường → gần tâm nhưng kẹt (36-52s)
Lần 5: Ball rất nhỏ, đi đến cuối → chạm emoji → WIN! 🎉 (52-65s)
→ Hiệu ứng nổ tung thỏa mãn + fade out (65-75s)
```

---

## 2. THÔNG SỐ KỸ THUẬT

### 2.1. Viewport
| Thông số | Giá trị |
|---|---|
| Resolution | 1080 × 1920 (9:16) |
| Window size | 405 × 720 (scale down cho desktop) |
| FPS | 60 |
| Renderer | Godot Mobile 2D |
| Background | Màu đen thuần (#000000) |

### 2.2. Xoắn Ốc (Spiral — dạng vỏ ốc 2D)

**Hướng:** Từ NGOÀI VÀO TRONG (θ=0 ở ngoài, θ tăng = vào tâm)

| Thông số | Giá trị | Ghi chú |
|---|---|---|
| Khoảng cách vòng ngoài (max) | 80.0 px | Vòng ngoài cùng rộng nhất |
| Khoảng cách vòng trong (min) | 22.0 px | Vòng trong cùng hẹp nhất |
| Thu hẹp | Tuyến tính từ max → min | `gap(θ) = lerp(80, 22, θ/θ_max)` |
| Số vòng | 5.5 | Có điểm dừng (không loop) |
| Miệng spiral | Góc 3h (bên phải) | θ=0 hướng phải |
| Cuối spiral | Gần tâm viewport | Nơi đặt emoji 😊 |
| Tâm | Vector2(540, 960) | Trung tâm viewport |
| Điểm/vòng | 120 | Độ mịn đường cong |

**Công thức bán kính:**
```
r(θ) = R_max - ∫₀^θ gap(t)/(2π) dt

Với gap(t) = lerp(80, 22, t/θ_max)
→ r(θ) = R_max - (1/2π) × [80×θ - 58×θ²/(2×θ_max)]
```

### 2.3. Tam Giác (Equilateral Triangle)
| Thông số | Giá trị | Ghi chú |
|---|---|---|
| Hình dạng | **Tam giác đều** | 3 cạnh bằng nhau |
| Cạnh | 24.0 px | Cố định |
| Khoảng cách đến spiral | 4.0 px | Cách đường line phía trước (hướng tâm) |
| Đỉnh hướng | Vào tâm | Đỉnh tam giác chỉ về tâm spiral |
| Mật độ | 1 tam giác / 11.25° | ~32 tam giác/vòng |
| Màu sắc | Gradient cầu vồng theo vòng | Ngoài đỏ/cam → trong xanh/tím |
| Render | `MultiMeshInstance2D` | 1 draw call |
| Collision | Circle approximation | `radius = side × 0.45` |

### 2.4. Quả Bóng
| Thông số | Giá trị | Ghi chú |
|---|---|---|
| Tốc độ | 420.0 px/s | Không đổi |
| Shrink per bounce | 1.5 px | Mỗi lần chạm tường spiral |
| Bán kính tối thiểu | 5.0 px | Không co nhỏ hơn |
| Màu | Trắng (#FFFFFF) | |
| Spawn | Cách miệng spiral 20px ra ngoài | Hướng 3h |
| Hướng ban đầu | Tiếp tuyến CW + hơi vào trong | Đi vào miệng spiral |
| Node type | `Node2D` (custom physics) | KHÔNG dùng RigidBody2D |

### 2.5. Tường Spiral
- Đường xoắn ốc chính là tường — ball nảy khi chạm
- Normal hướng ra ngoài (ball nảy vào trong)
- Khe hở: 3 segment đầu tiên (miệng) — ball đi qua không nảy
- Spiral có **điểm dừng** (cuối) — không loop vô tận

### 2.6. Emoji (Win Target)
| Thông số | Giá trị |
|---|---|
| Ký tự | 😊 |
| Font size | 48 |
| Vị trí | Cuối spiral (gần tâm) |
| Win radius | ball.radius + 20px |

---

## 3. AUTO-TEST: 5 NGƯỠNG BALL RADIUS

### 3.1. Nguyên lý

Simulation chạy **5 lần liên tiếp** với ball có kích thước giảm dần. Mỗi lần, ball đi sâu hơn vào spiral. Lần cuối ball đủ nhỏ để đi đến emoji ở tâm.

**Cơ chế dừng:** Ball bị kẹt khi `diameter (2×radius) >= khoảng cách vòng tại vị trí đó`. Vì khoảng cách vòng thu hẹp dần (80→22px), ball lớn bị kẹt sớm, ball nhỏ đi sâu hơn.

### 3.2. Tính toán 5 ngưỡng

Khoảng cách vòng tại vị trí t (0=ngoài, 1=trong):
```
gap(t) = lerp(80, 22, t) = 80 - 58×t
```

Ball bị kẹt khi `2×radius >= gap(t)`, tức `t_stop = (80 - 2×radius) / 58`

| Lần | Mục tiêu đi được | t_stop | gap tại đó | Ball radius | Ball diameter |
|-----|-------------------|--------|------------|-------------|---------------|
| 1 | 1/10 đường | 0.10 | 74.2 px | **37 px** | 74 px |
| 2 | 3/10 đường | 0.30 | 62.6 px | **31 px** | 62 px |
| 3 | 5/10 đường | 0.50 | 51.0 px | **25 px** | 50 px |
| 4 | 8/10 đường | 0.80 | 33.6 px | **16 px** | 32 px |
| 5 | 10/10 (WIN) | 1.00 | 22.0 px | **9 px** | 18 px < 22 |

### 3.3. Cấu hình Auto-Test

```gdscript
const TEST_RADII: Array[float] = [37.0, 31.0, 25.0, 16.0, 9.0]
const TEST_TIMEOUT: float = 20.0  # Giây — nếu ball không tiến thêm → next
```

### 3.4. Flow Auto-Test

```
[Lần 1] Ball radius = 37px
  → Ball đi vào spiral, đi được ~1/10 đường
  → Bị kẹt (diameter 74 ≈ gap 74.2 tại t=0.1)
  → Timeout 20s → Reset

[Lần 2] Ball radius = 31px
  → Đi được ~3/10 đường
  → Bị kẹt (diameter 62 ≈ gap 62.6 tại t=0.3)
  → Timeout → Reset

[Lần 3] Ball radius = 25px
  → Đi được ~5/10 đường
  → Bị kẹt (diameter 50 ≈ gap 51 tại t=0.5)
  → Timeout → Reset

[Lần 4] Ball radius = 16px
  → Đi được ~8/10 đường
  → Bị kẹt (diameter 32 ≈ gap 33.6 tại t=0.8)
  → Timeout → Reset

[Lần 5] Ball radius = 9px
  → Diameter 18 < min gap 22 → đi được đến cuối!
  → Chạm emoji 😊 → WIN! 🎉
  → Burst particles + fade out
```

### 3.5. Phát hiện "bị kẹt"

Ball bị kẹt khi:
- Đã bounce > 5 lần VÀ
- Không tiến gần tâm thêm trong 3 giây liên tiếp

Hoặc đơn giản: **timeout 20 giây** cho mỗi lần test.

### 3.6. Hiệu ứng chuyển lần và Xuất hiện Tam Giác (Spawn Animation)

Giữa mỗi lần test (và khi bắt đầu simulation):
1. Ball dừng, flash trắng nhấp nháy 0.3s (phục vụ hiệu ứng chuyển cảnh).
2. Reset trạng thái tất cả tam giác (hiện lại).
3. **Hoạt ảnh xuất hiện Tam giác (Triangle Spawn Animation):** Chạy hiệu ứng sóng lan truyền (wave pattern) từ ngoài vào trong. Tất cả các tam giác ban đầu có tỷ lệ scale = 0.0, sau đó phóng to lên kích thước thực tế (scale 1.0) theo thứ tự từ vòng ngoài (index thấp) vào vòng trong (index cao). Thời gian lan truyền khoảng 0.35 giây, mỗi tam giác mất 0.15 giây để scale up hoàn chỉnh.
4. Ball mới xuất hiện ở miệng spiral (bán kính nhỏ hơn lần trước).
5. Delay 0.5s → bắt đầu lần mới (kích hoạt ball chạy).

---

## 4. WIN CONDITION

- **Win:** Ball chạm emoji 😊 ở cuối spiral
  - `distance(ball.position, spiral_end_position) < ball.radius + 20.0`
- **Chỉ xảy ra ở lần test cuối** (ball đủ nhỏ)
- Không có lose condition — simulation luôn chạy hết 5 lần

---

## 5. HIỆU ỨNG THỊ GIÁC (JUICE) & ANIMATIONS

### 5.1. Debris Particles (Mảnh vụn va chạm)
- Trigger: `brick_destroyed` signal
- Lấy từ `ObjectPool` (không tạo mới)
- Hình dáng: 3-6 mảnh vỡ dạng tam giác sắc nhọn ngẫu nhiên bay tự do theo trọng lực và tự xoay mượt mà.
- Màu sắc: Viền trắng (outline) kết hợp với màu gốc của tam giác vừa vỡ dưới dạng neon rực rỡ, phai mờ dần theo thời gian.
- Lifetime: 0.6s

### 5.2. Ball Trail (Đuôi bóng phát sáng)
- `Line2D` gradient trắng với độ mờ tăng dần về phía đầu bóng, thuôn nhọn dần về phía đuôi (dùng Curve).
- 20 điểm lưu vết, width bằng đường kính bóng (radius × 2.0).

### 5.3. Screen Shake
- Trigger: ball chạm tường spiral
- Intensity: `ball_radius / 54.0 × 3.0` px
- Decay: 0.15s
- (Lưu ý: Hiệu ứng rung màn hình đã được tắt theo yêu cầu người dùng).

### 5.4. Center Glow
- `PointLight2D` tại tâm, màu cam/vàng.
- Pulse: sin wave, period 2s.
- Win: burst to full brightness (energy → 8.0) → fade out.

### 5.5. Spiral Wall Visual
- `Line2D` trắng, width 4px, opacity 60% tạo cảm giác đường kẻ mảnh và sang trọng.

### 5.6. Win Effect & Dopamine Explosion (Hoạt ảnh thắng cuộc ở Test cuối)
Khi bóng ở lần test thứ 5 chạm emoji 😊 ở tâm:
- Phun 8 cụm hạt mảnh vụn neon từ tâm emoji tỏa ra các hướng.
- Center glow burst rực sáng rồi tắt dần.
- **Dopamine Neon Circles Explosion:** Hàng trăm vòng tròn rỗng với màu sắc cầu vồng neon sặc sỡ liên tục xuất hiện tại tâm và phình to lan rộng ra toàn màn hình.
  - Các vòng tròn được vẽ dạng neon kép: một vòng lõi sáng rõ nét chồng lên một vòng hào quang phát sáng rộng hơn, bán trong suốt (neon glow outline).
  - Tốc độ lan nở ngẫu nhiên 500-750 px/s, độ rộng viền ngẫu nhiên 6-14 px.
  - Phai mờ dần (fade out) trong 0.5 giây cuối của chu kỳ sống 2.2 giây.
- Hiệu ứng Emoji Flood & Confetti: Hàng loạt emoji nảy tưng bừng tràn ngập màn hình kèm theo giấy vụn trang trí (confetti) rơi tự do trước khi kết thúc màn chơi.

---

## 6. HUD & SHORTS OVERLAY

HUD được thiết kế để tối ưu hiển thị Shorts (9:16) với bố cục premium:

### 6.1. Shorts Title Overlay
- **Nội dung:** Tiêu đề chữ lớn `"WILL THE BALLS GET TO CENTER"` chính giữa góc trên màn hình.
- **Thiết kế:** Dùng RichTextLabel với BBCode, font chữ đậm cỡ lớn (42px), đổ bóng viền đen dày nổi bật trên nền đen. Từ khóa **"CENTER"** được định dạng màu đỏ nổi bật (`#ff3333`) để thu hút ánh nhìn và tăng tính tương tác.

### 6.2. Thanh đo kích thước bóng (Ball Size Indicator)
- **Vị trí:** Thanh đo dạng ống thẳng đứng nằm ở cạnh phải màn hình (x: 1030-1054, y: 200-500, cao 300px).
- **Cơ chế:**
  - Vạch đầy tương ứng với tỷ lệ kích thước hiện tại của bóng (giới hạn từ bán kính nhỏ nhất 15.0px đến lớn nhất 62.0px).
  - Màu sắc của thanh đo tự động cập nhật động dựa trên phần trăm: **Xanh lá** (bóng nhỏ, dưới 25%), **Vàng** (bóng trung bình, dưới 60%), và **Đỏ** (bóng lớn, trên 60%).
  - Đồng bộ thời gian thực qua tín hiệu từ EventBus khi bóng thay đổi bán kính.

### 6.3. Bảng thông số phụ
| Thông tin | Vị trí | Format |
|---|---|---|
| Ball radius | Dưới giữa | `Ball radius: {r:.1f} px` |
| Destroyed | Trên phải | `{n} / {total}` |
| Timer | Trên trái | `{mm:ss}` |
| FPS | Trên trái (dưới timer) | `FPS: {n}` (màu xanh nhạt để phân biệt) | |

---

## 7. COLLISION SYSTEM

### 7.1. Tam Giác
- Circle approximation: `collision_radius = side × 0.45`
- Spatial grid lookup (9 ô xung quanh ball)
- Check: `distance(ball, tri) < ball.radius + tri.collision_radius`

### 7.2. Tường Spiral
- Closest point on segment
- Normal hướng ra ngoài (ball nảy vào trong)
- Shrink ball 1.5px mỗi bounce

### 7.3. CCD
- Sub-steps: `steps = ceil(distance / (radius × 0.5))`
- Mỗi step: move → check triangle → check wall

### 7.4. Spatial Grid
- Cell size: 100px
- Update: xóa triangle khỏi grid khi vỡ

---

## 8. MILESTONES

| Milestone | Nội dung |
|---|---|
| M1 | Core: EventBus, ObjectPool, GameManager, GameScene |
| M2 | Spiral math: sinh points (ngoài→trong), khoảng cách thu hẹp |
| M3 | Render: MultiMesh tam giác đều + Line2D spiral |
| M4 | Ball physics: CCD, wall collision, shrink |
| M5 | Triangle collision + spatial grid |
| M6 | Effects: trail, debris, screen shake, center glow |
| M7 | HUD + win condition (chạm emoji) + reset |
| M8 | Auto-test 5 ngưỡng + polish |

---

## 9. CRITICAL GOTCHAS

**G1. Tốc độ bóng không đổi**
```gdscript
velocity = velocity.bounce(normal).normalized() * BALL_SPEED
```

**G2. Spiral hướng ngoài→trong**
θ=0 = vòng ngoài (miệng 3h), θ tăng = vào tâm. Bán kính GIẢM DẦN.

**G3. Khoảng cách thu hẹp dần**
`gap(θ) = lerp(80, 22, θ/θ_max)` — ball lớn bị kẹt ở ngoài, ball nhỏ đi sâu.

**G4. Ball bị kẹt = tự nhiên**
Không cần code check "ball quá lớn". Ball tự nhiên bị kẹt vì tường spiral hẹp hơn diameter. Dùng timeout để chuyển lần test.

**G5. Normal hướng ra ngoài**
Normal tường spiral hướng ra ngoài (từ tâm ra). Ball nảy vào trong khi chạm tường.

**G6. Emoji ở cuối spiral**
Cuối spiral = điểm cuối cùng trong `spiral_points[]` = gần tâm nhất.

**G7. Auto-test không shrink**
Trong auto-test, ball KHÔNG co nhỏ khi bounce. Mỗi lần test ball giữ nguyên radius ban đầu. Mục đích: test xem radius nào đi được bao xa.

---

## 10. THAM SỐ TUNING

Nếu clip quá ngắn/dài, điều chỉnh:

| Tham số | Tăng → | Giảm → |
|---------|--------|--------|
| `TEST_TIMEOUT` | Mỗi lần test lâu hơn | Clip ngắn hơn |
| `BALL_SPEED` | Game nhanh hơn | Game chậm hơn |
| `SPIRAL_TURNS` | Nhiều vòng hơn, clip dài | Ít vòng, clip ngắn |
| `SPIRAL_GAP_MAX` | Vòng ngoài rộng hơn | Spiral nhỏ hơn |
| `SPIRAL_GAP_MIN` | Vòng trong rộng hơn (dễ) | Khó hơn |

---

## 11. CHI TIẾT TRIỂN KHAI THIẾT KẾ VISUAL & ANIMATION (IMPLEMENTATION SPECS)

Để đạt hiệu năng tối ưu (Zero GC runtime, 1 draw call) nhưng vẫn đảm bảo tính thẩm mỹ cực cao (Premium Visuals), các cơ chế đồ họa và hoạt ảnh được cài đặt chi tiết như sau:

### 11.1. Cấu trúc Hình học Tam giác Cung đáy rỗng (Shield MultiMesh)
- **Thiết kế đỉnh:** Mỗi tam giác trong hệ thống MultiMesh được cấu thành từ 12 đỉnh (6 đỉnh ngoài, 6 đỉnh trong) để tạo hình khiên rỗng cong mềm ở cạnh đáy:
  - Vòng ngoài: Xác định khung bao bên ngoài của tam giác với đỉnh nhọn và cạnh đáy lõm về phía tâm local.
  - Vòng trong: Bằng 75% kích thước vòng ngoài (scale factor = 0.75).
- **Màu sắc & Ánh sáng:**
  - Vòng ngoài sử dụng màu HDR có cường độ cao `Color(2.5, 2.5, 2.5, 1.0)` nhân với màu gradient cầu vồng của tam giác. Khi đi qua WorldEnvironment Glow, các cạnh ngoài sẽ phát sáng rực rỡ (Neon Glow).
  - Vòng trong sử dụng màu xám tối và bán trong suốt `Color(0.1, 0.1, 0.1, 0.2)` để làm nổi bật thiết kế rỗng và tránh làm chói mắt người xem khi số lượng tam giác quá nhiều.

### 11.2. Hoạt ảnh xuất hiện dạng Sóng (Spawn Wave Animation)
- **Thuật toán lan truyền:** Các tam giác được sinh theo chiều từ ngoài vào trong dựa trên thứ tự chỉ mục `i` của mảng từ `0` đến `total_instances - 1`.
- **Trễ pha lan sóng:** Trễ pha xuất hiện của tam giác thứ `i` được tính bằng:
  `delay_i = (i / total_instances) * 0.35` (giây)
- **Tốc độ phóng to:** Sau khi hết thời gian trễ, tỷ lệ scale của tam giác tăng tuyến tính từ `0.0` đến `1.0` trong vòng `0.15` giây:
  `scale_i = clamp((elapsed_time - delay_i) / 0.15, 0.0, 1.0)`
- Sau `0.5` giây, toàn bộ vòng xoắn ốc tam giác sẽ hiện lên đầy đủ và bóng sẽ được phóng đi, tạo cảm giác mượt mà và sinh động.

### 11.3. Vòng tròn Dopamine Thắng cuộc (Neon Circles)
- **Vẽ động Zero-GC:** Vòng tròn được vẽ trực tiếp bằng lệnh `draw_arc` trong hàm `_draw()` của lớp `DopamineEmojiExplosion` mà không khởi tạo các Node hình học riêng rẽ.
- **Hiệu ứng Neon viền kép (Double-arc):** Mỗi vòng tròn neon phồng ra từ tâm được vẽ bằng 2 nét xếp chồng:
  - **Nét hào quang mờ (Outer Glow):** Vẽ với độ rộng viền `width * 2.5` và màu sắc mờ `Color(r, g, b, alpha * 0.35)` tạo ánh sáng neon tỏa rộng xung quanh.
  - **Nét lõi sáng (Inner Core):** Vẽ với độ rộng viền `width` và màu sắc sắc nét `Color(r, g, b, alpha)` làm tâm điểm sáng rõ.
- **Thông số động:** Bán kính tăng từ `0` với tốc độ ngẫu nhiên `500-750 px/s`, độ dày viền `6-14 px`, tự biến đổi màu cầu vồng theo thời gian thực và phai mờ (fade-out) trong `0.5s` cuối của chu kỳ sống `2.2s`.

### 11.4. Vật lý Hạt Confetti & Emoji
- **Emoji Flooding:** Khi kích hoạt Phase 2 của màn thắng, 120 Emojis được phun liên tục từ tâm xoắn ốc và miệng xoắn ốc.
  - **Vật lý:** Chịu gia tốc trọng trường rơi tự do `350 px/s²`, nảy đàn hồi (bouncing) hoàn toàn khi chạm biên viewport (trái/phải/trên/dưới).
  - **Chuyển động tự xoay:** Tự xoay quanh trục với vận tốc góc ngẫu nhiên `-6.0` đến `6.0` rad/s.
- **Confetti Rơi tự do:** Các mảnh giấy vụn hình chữ nhật được sinh ngẫu nhiên ở đỉnh màn hình và tâm.
  - **Hiệu ứng lượn sóng (Swaying):** Mảnh giấy rơi chịu hiệu ứng gió lượn sóng ngang hình sin:
    `sway_force = cos(sway_phase) * sway_width`
    Trong đó `sway_phase` tăng đều theo thời gian, `sway_width` ngẫu nhiên từ `20.0` đến `60.0` px để tạo hiệu ứng rơi nhẹ nhàng chân thực.
