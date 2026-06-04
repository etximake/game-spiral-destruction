# Obstacle Shape Variants Design

**STATUS:** ✅ DA TRIEN KHAI (2026-05-27) — Phases 1-5 tat ca shape, fill_style, shape_factor

Muc tieu: cho phep thay visual obstacle trong spiral tu triangle sang square, circle, hoac style lap day, nhung giu performance va collision hien tai.

---

### ✅ Implementation summary

| Feature | Status | File |
|---------|--------|------|
| `shape` config field | ✅ | `config.json` → `triangles.shape` |
| `fill_style` config field | ✅ | `config.json` → `triangles.fill_style` (default: `wall_attached`) |
| `_create_obstacle_mesh(shape)` | ✅ | `SpiralRenderController.gd` |
| Triangle mesh (unchanged) | ✅ | `SpiralRenderController._create_triangle_mesh()` |
| Square mesh | ✅ | `SpiralRenderController._create_square_mesh()` |
| Circle mesh | ✅ | `SpiralRenderController._create_circle_mesh()` |
| Diamond mesh (bonus) | ✅ | `SpiralRenderController._create_diamond_mesh()` |
| Hexagon mesh (bonus) | ✅ | `SpiralRenderController._create_hexagon_mesh()` |
| `shape_factor` sizing | ✅ | `SpiralMapController._get_shape_factor()` |
| Collision unchanged | ✅ | Circle approximation via `collision_radius` |

---

## 1. Hien trang

Hien code dang dung ten `triangles` o ca config va data:

- `config.json` section `triangles`
- `SpiralMapController._tri_cfg`
- `SpiralMapController.triangles`
- `SpiralRenderController._create_triangle_mesh()`
- `Ball.gd._check_triangle_collisions()`
- signal `brick_destroyed`

Vi vay phase dau khong doi ten bien public `triangles`. Chi them shape/style vao config.

---

## 2. Nguyen tac bat buoc

1. Van dung `MultiMeshInstance2D`.
2. Tat ca instance cung mot mesh trong mot run.
3. Collision giai doan dau van la circle approximation.
4. Data dictionary cua moi obstacle giu nguyen keys hien tai.
5. `Ball.gd` khong can biet obstacle la triangle/square/circle.
6. Khong tao Node2D rieng cho tung obstacle.

---

## 3. Schema config de xuat

Phuong an an toan: mo rong section `triangles` hien co:

```json
"triangles": {
  "shape": "triangle",
  "fill_style": "wall_attached",
  "angle_step_deg": 11.25,
  "gap_from_wall": 0.0,
  "collision_ratio": 0.25,
  "min_size": 5.0,
  "max_size": 100.0,
  "size_ratio": 0.8,
  "spacing_ratio": 1.15,
  "mesh": {
    "outer_brightness": 2.5,
    "inner_brightness": 0.3,
    "inner_alpha": 0.9,
    "hollow_scale": 0.7
  }
}
```

Gia tri `shape` hop le:

```text
triangle
square
circle
diamond
hexagon
```

Phase dau chi can implement:

```text
triangle, square, circle
```

Neu muon section moi ve sau:

```json
"obstacles": {
  "shape": "square"
}
```

Thi code phai fallback:

```gdscript
var obstacle_cfg: Dictionary = config.get("obstacles", config.get("triangles", {}))
```

Nhung trong phase dau nen giu `triangles` de it rui ro.

---

## 4. Render design

Trong `SpiralRenderController.gd`, thay:

```gdscript
var mesh: ArrayMesh = _create_triangle_mesh()
```

Bang:

```gdscript
var shape: String = _tri_cfg.get("shape", "triangle")
var mesh: ArrayMesh = _create_obstacle_mesh(shape)
```

Them:

```gdscript
func _create_obstacle_mesh(shape: String) -> ArrayMesh:
    match shape:
        "square":
            return _create_square_mesh()
        "circle":
            return _create_circle_mesh()
        _:
            return _create_triangle_mesh()
```

### Triangle

Dung mesh hien tai. Khong sua neu khong can.

### Square

Mesh local size 1.0, origin tai tam.

Outer vertices:

```text
(-0.5,-0.5), (0.5,-0.5), (0.5,0.5), (-0.5,0.5)
```

Neu muon hollow neon, tao outer ring + inner ring scale `hollow_scale`.

### Circle

Tao polygon fan hoac ring voi segment config:

```json
"mesh": {
  "circle_segments": 24
}
```

Default 24 segment. Khong can qua cao.

---

## 5. Placement design

`SpiralMapController._generate_triangles()` co the giu nguyen logic placement:

- `pos`
- `base_pos`
- `to_center`
- `angle`
- `size`
- `collision_radius`

Voi shape moi:

```gdscript
var shape: String = _tri_cfg.get("shape", "triangle")
```

Angle:

| Shape | Angle rule |
|---|---|
| triangle | apex huong vao tam: current rule |
| square | co the xoay theo tangent hoac huong vao tam; phase dau dung current angle |
| circle | angle khong quan trong |

Size:

Van dung:

```gdscript
var max_possible_size: float = (local_gap - TRIANGLE_GAP) / 0.866
var size: float = clamp(max_possible_size * TRI_SIZE_RATIO, TRI_MIN_SIZE, TRI_MAX_SIZE)
```

Nhung voi square/circle, he so 0.866 khong hoan toan dung. De an toan phase dau:

```gdscript
var shape_factor: float = 0.866
if shape == "square":
    shape_factor = 1.414
elif shape == "circle":
    shape_factor = 2.0
var max_possible_size: float = (local_gap - TRIANGLE_GAP) / shape_factor
```

Y nghia `size`:

| Shape | `size` la |
|---|---|
| triangle | canh/x scale mesh nhu hien tai |
| square | canh hinh vuong |
| circle | duong kinh circle visual |

Neu muon tranh thay doi behavior qua nhieu, co the giu cong thuc cu trong phase dau va chi tune config.

---

## 6. Collision design

Hien collision:

```gdscript
dist < ball.radius + tri["collision_radius"]
```

Giu nguyen.

Collision radius:

```gdscript
"collision_radius": size * TRIANGLE_COLLISION_RATIO
```

Goi y config:

| Shape | collision_ratio |
|---|---|
| triangle | 0.25 - 0.45 |
| square | 0.45 - 0.60 |
| circle | 0.50 |

Khong implement SAT/polygon collision trong phase dau.

---

## 7. Fill style design

Them optional:

```json
"triangles": {
  "fill_style": "wall_attached"
}
```

Gia tri:

```text
wall_attached
dense
center_lane
filled_channel
```

Phase dau chi implement:

1. `wall_attached`: logic hien tai.
2. `dense`: giam spacing bang config, khong can code moi.

Chua nen implement `filled_channel` ngay vi no thay doi gameplay nhieu.

Neu implement `filled_channel` ve sau:

- Moi theta tao nhieu obstacle theo chieu ngang channel.
- Can tao multiple lanes tu wall vao center.
- Phai dam bao khong lap len spiral wall va emoji.
- Can cap nhat spatial grid va instance count.

---

## 8. Checklist implementation — STATUS 2026-05-27

- [x] Them `shape` vao config default, default `"triangle"`.
- [x] Them getter shape trong `SpiralRenderController` (qua `_tri_cfg.get("shape", "triangle")`).
- [x] Them `_create_obstacle_mesh(shape)`.
- [x] Giu `_create_triangle_mesh()` hien tai.
- [x] Them `_create_square_mesh()`.
- [x] Them `_create_circle_mesh()`.
- [x] Upload transform/color nhu cu.
- [x] Khong sua `Ball.gd` collision.
- [x] Tune `collision_ratio`, `size_ratio`, `spacing_ratio` cho tung variant (qua variant config files).
- [x] Them `fill_style` config field (default `"wall_attached"`, `"dense"` = reduce spacing via config).
- [x] Them `_get_shape_factor(shape)` trong `SpiralMapController` cho size estimation dung voi moi shape.
- [x] Bonus: them `diamond` va `hexagon` mesh.

### Deferred (chua implement, khong can trong phase dau)

- [ ] `fill_style = "center_lane"` — can logic moi trong `_generate_triangles()`.
- [ ] `fill_style = "filled_channel"` — can multiple obstacles per theta, redesign.
- [ ] SAT/polygon collision — collision van la circle approximation.

---

## 9. Test cases bat buoc — STATUS

1. ✅ Default triangle chay khong loi. (shape="triangle" fallback)
2. ✅ Square render dung 1 MultiMesh. (_create_square_mesh)
3. ✅ Circle render dung 1 MultiMesh. (_create_circle_mesh)
4. ⚠️ Ball pha obstacle binh thuong. (Can test visual)
5. ⚠️ Regrow animation van dung voi shape moi. (Can test visual)
6. ⚠️ Spawn wave animation van dung. (Can test visual)
7. ✅ Obstacle khong de len emoji. (stop_distance_from_center van hoat dong)
8. ⚠️ FPS khong giam ro ret. (Can benchmark)

---

## 10. Khong duoc lam — STATUS

- [x] Khong doi `Ball` sang `RigidBody2D`. ✅
- [x] Khong dung sprite alpha/texture de collision. ✅
- [x] Khong tao Node2D rieng cho tung obstacle. ✅ (van 1 MultiMesh)
- [x] Khong xoa MultiMesh. ✅
- [x] Khong doi ten `triangles` public. ✅
- [x] Khong doi collision circle sang polygon. ✅

- [ ] Khong doi `triangles` array thanh `obstacles` trong phase dau.
- [ ] Khong tao moi obstacle la Sprite2D/Node2D.
- [ ] Khong sua win condition.
- [ ] Khong sua wall collision.
- [ ] Khong bo spatial grid.
- [ ] Khong implement filled channel truoc khi square/circle on dinh.
