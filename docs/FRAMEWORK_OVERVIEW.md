# 🎬 GODOT CONTENT ENGINE — FRAMEWORK OVERVIEW
**Phiên bản:** 1.0  
**Cập nhật:** 2026-05-21  
**Engine:** Godot 4.5  
**Mục tiêu xuất bản:** Video Shorts (9:16, 1080×1920)

---

## 1. TINH THẦN CỐT LÕI

> **Godot không phải là game engine trong dự án này. Godot là một máy quay phim.**

Mục tiêu không phải tạo ra một game để người chơi tương tác. Mục tiêu là sản xuất **nội dung video ngắn dạng simulation** — những đoạn clip "Oddly Satisfying" / "Brain Rot" / "Hypnotic" có khả năng viral trên TikTok, YouTube Shorts, Instagram Reels.

Mỗi **Simulation Mode** là một màn trình diễn thị giác độc lập:
- Tự động chạy từ đầu đến cuối (không cần người chơi)
- Có điểm bắt đầu rõ ràng, diễn biến hấp dẫn, kết thúc thỏa mãn
- Tối ưu cho màn hình dọc 9:16
- Render ổn định 60 FPS để quay bằng OBS hoặc export video

---

## 2. ĐỊNH NGHĨA SIMULATION MODE

Một Simulation Mode là một scene Godot độc lập, tuân thủ **SimulationBase interface**, bao gồm:

| Thành phần | Mô tả |
|---|---|
| **Setup Phase** | Khởi tạo trạng thái ban đầu (sinh hình học, đặt vật thể) |
| **Run Phase** | Simulation tự chạy, không cần input |
| **Climax** | Khoảnh khắc đỉnh điểm thị giác (tất cả vỡ, đạt tâm, v.v.) |
| **End State** | Màn hình kết thúc đẹp, loop lại hoặc fade out |
| **Duration** | Mục tiêu 30–90 giây mỗi clip |

---

## 3. DANH SÁCH MODE ĐÃ ĐỊNH NGHĨA / KẾ HOẠCH

| ID | Tên Mode | Mô tả ngắn | Trạng thái |
|---|---|---|---|
| M01 | **Spiral Destruction** | Bóng nảy trong xoắn ốc, co nhỏ dần vào tâm | ✅ Hoàn thành |
| M02 | **Domino Chain** | Chuỗi domino đổ theo pattern hình học | 📋 Ý tưởng |
| M03 | **Sand Falling** | Cát rơi lấp đầy hình dạng phức tạp | 📋 Ý tưởng |
| M04 | **Bubble Sort Visual** | Thuật toán sắp xếp được visualize bằng màu sắc | 📋 Ý tưởng |
| M05 | **Fractal Growth** | Hình fractal tự sinh trưởng theo thời gian | 📋 Ý tưởng |

---

## 4. NGUYÊN TẮC THIẾT KẾ CHUNG (DESIGN PRINCIPLES)

### 4.1. Visual First
- Màu sắc phải rực rỡ, tương phản cao trên nền đen
- Mỗi frame phải "đẹp" kể cả khi pause
- Hiệu ứng particle và trail là bắt buộc, không phải tùy chọn

### 4.2. Satisfying Arc
Mỗi clip phải có cấu trúc cảm xúc:
```
Tò mò (0-5s) → Hiểu pattern (5-15s) → Hồi hộp (15-40s) → Thỏa mãn (40-60s) → Kết thúc đẹp
```

### 4.3. Zero Interaction Required
- Simulation tự chạy hoàn toàn
- Không có UI game (nút bấm, menu)
- HUD chỉ hiển thị thông số thú vị (Ball radius, Score, Timer) như một lớp thông tin thêm

### 4.4. Loop-Friendly
- Kết thúc clip phải có thể loop mượt mà hoặc fade to black sạch
- Reset tức thì (< 0.5s) để quay nhiều take

---

## 5. KPI SẢN XUẤT

| Chỉ số | Mục tiêu |
|---|---|
| FPS khi record | 60 FPS ổn định |
| Thời lượng clip | 30–90 giây |
| Thời gian reset | < 0.5 giây |
| Số mode có thể mở rộng | Không giới hạn |
| Viewport | 1080 × 1920 (9:16) |
| Renderer | Godot Mobile 2D |

---

## 6. WORKFLOW SẢN XUẤT NỘI DUNG

```
[Ý tưởng Mode mới]
        ↓
[Viết GDD cho Mode đó]  ←── Template: docs/TEMPLATE_MODE_GDD.md
        ↓
[Implement theo Milestones]
        ↓
[Test visual trong Godot Editor]
        ↓
[Record bằng OBS / Godot Movie Writer]
        ↓
[Edit + Upload Shorts]
```

---

## 7. CÔNG CỤ RECORD KHUYẾN NGHỊ

**Godot Movie Writer** (built-in):
- Bật `movie_file` trong Project Settings
- Export video trực tiếp từ Godot, không cần OBS
- Đảm bảo mỗi frame được render đúng, không bị drop

**OBS Studio** (thay thế):
- Capture Godot window
- Dùng khi cần record real-time với audio

---

## 8. MỞ RỘNG FRAMEWORK

Khi thêm một Mode mới, developer chỉ cần:
1. Copy `docs/TEMPLATE_MODE_GDD.md` → điền thông tin
2. Tạo scene mới trong `res://Modes/{ModeName}/`
3. Implement `SimulationBase` interface (xem `docs/ARCHITECTURE.md`)
4. Đăng ký vào `ModeRegistry` trong `GameManager.gd`

Không cần sửa bất kỳ code core nào.
