# 🎮 GDD — MODE: {MODE_NAME}
**Mode ID:** `{mode_id}`  
**Phiên bản:** 1.0  
**Framework:** Godot Content Engine (xem `ARCHITECTURE.md`)  
**Thời lượng clip mục tiêu:** {X}–{Y} giây

---

## 1. MÔ TẢ MODE

> Mô tả ngắn gọn simulation này làm gì và tại sao nó thú vị để xem.

**Vòng cảm xúc của clip:**
```
[Giai đoạn 1: Tò mò] (0-Xs)
→ [Giai đoạn 2: Hiểu pattern] (X-Ys)
→ [Giai đoạn 3: Hồi hộp] (Y-Zs)
→ [Climax: Thỏa mãn] (Z-Ws)
→ [Kết thúc] (W-ends)
```

---

## 2. THÔNG SỐ KỸ THUẬT

### 2.1. Viewport
| Thông số | Giá trị |
|---|---|
| Resolution | 1080 × 1920 (9:16) |
| FPS | 60 |
| Renderer | Godot Mobile 2D |
| Background | #000000 |

### 2.2. Thông số chính của simulation
| Thông số | Giá trị | Ghi chú |
|---|---|---|
| ... | ... | ... |

### 2.3. Thực thể chính (Main Entity)
| Thông số | Giá trị | Ghi chú |
|---|---|---|
| ... | ... | ... |

---

## 3. SIMULATION LOOP

```
[SETUP]
1. ...

[RUNNING - mỗi frame]
2. ...

[END STATE]
3. ...
```

---

## 4. WIN / END CONDITION

- **Kết thúc khi:** ...
- **Không có lose condition** (hoặc mô tả nếu có)

---

## 5. HIỆU ỨNG THỊ GIÁC (JUICE)

### 5.1. Particles
- ...

### 5.2. Visual Effects
- ...

### 5.3. Âm Thanh
- ...

---

## 6. HUD

| Thông tin | Vị trí | Format |
|---|---|---|
| ... | ... | ... |

---

## 7. COLLISION / INTERACTION SYSTEM

> Mô tả cách các thực thể tương tác với nhau. Không dùng Godot Physics cho geometry tĩnh.

---

## 8. MILESTONES TRIỂN KHAI

| Milestone | Nội dung | File chính |
|---|---|---|
| M1 | Core singletons (tái dùng từ framework) | `Core/Autoloads/` |
| M2 | ... | ... |
| M3 | ... | ... |

---

## 9. CRITICAL GOTCHAS

> Liệt kê các vấn đề kỹ thuật đặc thù của mode này cần chú ý khi implement.

**G1. ...**

**G2. ...**
