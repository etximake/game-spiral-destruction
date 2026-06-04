# DeepSeek Implementation Checklist - Spiral Content Variants

**Trang thai:** ✅ HOAN THANH (2026-05-27)  
**Da trien khai:** Phase 1 → Phase 5 day du

---

## ✅ Tien do tong quan

| Phase | Noi dung | Trang thai | Ngay |
|-------|----------|-----------|------|
| 1 | Content title & target emoji | ✅ Done | 2026-05-27 |
| 2 | Ball sprite skin | ✅ Done | 2026-05-27 |
| 3 | Obstacle shape variants | ✅ Done | 2026-05-27 |
| 4 | Variant config files | ✅ Done | 2026-05-27 |
| 5 | Variant loader (GameManager) | ✅ Done | 2026-05-27 |

### Da tao 3 variant

| Variant ID | Emoji | Shape | Ball visual |
|------------|-------|-------|-------------|
| `diamond_fireball_square` | 💎 | square | fireball sprite |
| `pizza_soccer_circle` | 🍕 | circle | soccer sprite |
| `heart_coin_triangle` | ❤️ | triangle | coin sprite |

### Files da sua/tao

```
SUA:
  Core/Autoloads/GameManager.gd
  Modes/SpiralDestruction/config.json
  Modes/SpiralDestruction/SpiralMode.gd
  Modes/SpiralDestruction/Entities/Ball.gd
  Modes/SpiralDestruction/Systems/SpiralRenderController.gd
  UI/HUD.gd

TAO MOI:
  Modes/SpiralDestruction/variants/diamond_fireball_square.json
  Modes/SpiralDestruction/variants/pizza_soccer_circle.json
  Modes/SpiralDestruction/variants/heart_coin_triangle.json
```

### Cach su dung variant

```gdscript
# Default (config.json)
GameManager.start_mode("spiral")

# Variant
GameManager.start_mode("spiral", "diamond_fireball_square")
GameManager.start_mode("spiral", "pizza_soccer_circle")
GameManager.start_mode("spiral", "heart_coin_triangle")
```

---

## 0. Context bat buoc phai doc truoc khi code

Doc cac file:

```text
docs/ARCHITECTURE.md
docs/CONFIG_SCHEMA.md
Modes/SpiralDestruction/designs/GDD_SpiralDestruction.md
Modes/SpiralDestruction/designs/CONTENT_VARIANTS_PLAN.md
Modes/SpiralDestruction/designs/BALL_SKIN_RESOURCE_DESIGN.md
Modes/SpiralDestruction/designs/OBSTACLE_SHAPE_VARIANTS_DESIGN.md
Modes/SpiralDestruction/config.json
Modes/SpiralDestruction/SpiralMode.gd
Modes/SpiralDestruction/Entities/Ball.gd
Modes/SpiralDestruction/Systems/SpiralMapController.gd
Modes/SpiralDestruction/Systems/SpiralRenderController.gd
```

---

## 1. Rules for AI agent

1. Do not rewrite whole files.
2. Do not refactor unrelated systems.
3. Do not change node hierarchy unless the checklist explicitly says so.
4. Do not change Godot physics model; this mode uses custom physics.
5. Do not remove current config fields.
6. Every new config field must have fallback default.
7. Default `config.json` must keep working.
8. Prefer small functions and local changes.
9. Print warnings for missing assets, do not crash.
10. Keep backward compatibility with section `triangles`.

---

## 2. Phase 1 - Content title and target emoji

### Goal

Allow each video variant to change quote/title and center emoji through a new optional `content` section.

### Files to edit

```text
Modes/SpiralDestruction/config.json
Modes/SpiralDestruction/SpiralMode.gd
UI/HUD.gd
```

Only edit `UI/HUD.gd` if HUD currently reads `hud.title` directly.

### Config change

Add this section to `config.json`:

```json
"content": {
  "variant_id": "default",
  "title": "WILL THE BALLS GET TO CENTER",
  "target_emoji": "\uD83D\uDE0A",
  "description": "Default Spiral Destruction content variant."
}
```

### SpiralMode change

In `_create_end_emoji()`, use:

```gdscript
var content_cfg: Dictionary = _config.get("content", {})
var emoji_char: String = content_cfg.get("target_emoji", _win_effect_cfg.get("emoji", "\uD83D\uDE0A"))
```

Do not remove fallback to `_win_effect_cfg`.

### HUD change

Where HUD title is initialized, prefer:

```gdscript
var content_cfg: Dictionary = config.get("content", {})
var title: String = content_cfg.get("title", hud_cfg.get("title", ""))
```

If HUD does not receive full config, update the place that emits/sets title. Do not redesign HUD.

### Done when

- [x] Default title still appears.
- [x] Default emoji still appears.
- [x] Changing `content.title` changes HUD.
- [x] Changing `content.target_emoji` changes center emoji.
- [x] Missing `content` section does not crash.

**Implementation notes:** `config.json` added `content` section with `variant_id:"default"`, `title`, `target_emoji`. `SpiralMode._create_end_emoji()` reads `content.target_emoji` → fallback `win_effect.emoji`. `HUD._load_hud_config()` reads `content.title` → fallback `hud.title`. Default behavior identical to before.

---

## 3. Phase 2 - Ball sprite skin

### Goal

Add optional sprite visual for ball. Physics remains circle.

### Files to edit

```text
Modes/SpiralDestruction/config.json
Modes/SpiralDestruction/Entities/Ball.gd
Modes/SpiralDestruction/SpiralMode.tscn
```

If editing `.tscn` is risky, create `Sprite2D` once in `Ball.gd._ready()` instead.

### Config change

Add to `ball`:

```json
"visual": {
  "type": "mesh",
  "sprite_path": "",
  "scale_to_radius": true,
  "rotation_enabled": false,
  "rotation_speed_multiplier": 1.0,
  "fallback_to_mesh": true
}
```

### Ball.gd implementation checklist

- [x] Add `Sprite2D` reference or create one once.
- [x] Parse `_visual_cfg = _ball_cfg.get("visual", {})`.
- [x] Implement `_apply_visual_config()`.
- [x] Implement `_update_visual_scale()`.
- [x] Radius setter calls `_update_visual_scale()`.
- [x] Mesh visual hidden when sprite visual is active.
- [x] Sprite visual hidden when mesh visual is active.
- [x] Missing sprite texture falls back to mesh.
- [x] `_physics_process(delta)` updates sprite rotation only if enabled.
- [x] `reset()` resets sprite rotation/distance.

### Do not change

- [x] Do not change `_move_with_ccd()`.
- [x] Do not change `_check_spiral_wall_collision()`.
- [x] Do not change `_check_triangle_collisions()`.
- [x] Do not use Sprite2D collision.

### Done when

- [x] `visual.type = "mesh"` works exactly as before.
- [x] `visual.type = "sprite"` with valid texture shows sprite.
- [x] Invalid `sprite_path` logs warning and shows mesh.
- [x] Auto-test still changes radius and sprite scale follows.
- [x] Win/stuck flow still works.

**Implementation notes:** `Ball.gd` creates `Sprite2D` once in `_ready()`. Default `_visual_type = "mesh"` keeps existing behavior. `set_ball_config()` parses `ball.visual`, calls `_apply_visual_config()`. `_update_visual_scale()` scales sprite by `radius * 2 / max(tex_size)`. Sprite rotation via `_distance_traveled_for_rotation`. No `.tscn` changes needed.

---

## 4. Phase 3 - Obstacle shape variants

### Goal

Allow obstacle mesh shape to be `triangle`, `square`, or `circle`.

### Files to edit

```text
Modes/SpiralDestruction/config.json
Modes/SpiralDestruction/Systems/SpiralRenderController.gd
```

Optional later:

```text
Modes/SpiralDestruction/Systems/SpiralMapController.gd
```

### Config change

Add to `triangles`:

```json
"shape": "triangle"
```

### RenderController checklist

- [x] In `_setup_multimesh()`, replace direct `_create_triangle_mesh()` call with `_create_obstacle_mesh(shape)`.
- [x] Add `_create_obstacle_mesh(shape: String)`.
- [x] Keep `_create_triangle_mesh()` unchanged.
- [x] Add `_create_square_mesh()`.
- [x] Add `_create_circle_mesh()`.
- [x] Both new meshes use local origin center and size near 1.0.
- [x] New meshes use vertex colors compatible with existing per-instance color.
- [x] Existing transform logic remains unchanged.

### Optional MapController shape tuning

Only do this after render shapes work:

- [ ] Read `shape` in `_generate_triangles()`. (SKIP — not needed for Phase 3, collision unchanged)
- [ ] Tune `shape_factor` for size estimation. (SKIP — collision remains circle approx)
- [ ] Keep dictionary keys unchanged. (Always preserved)
- [ ] Keep array name `triangles`. (Always preserved)

### Done when

- [x] `shape = "triangle"` output remains valid.
- [x] `shape = "square"` renders square obstacles.
- [x] `shape = "circle"` renders circle obstacles.
- [x] Ball can destroy all shapes.
- [x] Spawn/regrow animation works with all shapes.

**Implementation notes:** `SpiralRenderController.gd` added `_create_obstacle_mesh(shape: String)` factory dispatching to `_create_square_mesh()`, `_create_circle_mesh()`, `_create_diamond_mesh()`, `_create_hexagon_mesh()`. All meshes follow same hollow neon pattern: outer ring + inner ring scaled by `_mesh_hollow_scale`. Collision untouched — `Ball.gd` still uses `collision_radius`.

---

## 5. Phase 4 - Variant files

### Goal

Create ready-to-use config variants.

### Files/folders

```text
Modes/SpiralDestruction/variants/
```

Create:

```text
diamond_fireball_square.json
pizza_soccer_circle.json
heart_coin_triangle.json
```

### Rule

If no merge loader exists, these files should be full config copies, not partial overrides. This avoids ambiguity for AI and users.

### Required changes per variant

- [x] `content.variant_id`
- [x] `content.title`
- [x] `content.target_emoji`
- [x] `win_effect.emoji`
- [x] `hud.title`
- [x] `ball.initial_radius`
- [x] `ball.base_speed` or `auto_test.tests`
- [x] `ball.visual`
- [x] `triangles.shape`
- [x] `recording.output_path`

**Implementation notes:** Created 3 variant files as full config copies in `Modes/SpiralDestruction/variants/`. Each has unique emoji, title, ball params, shape, and recording path.

---

## 6. Phase 5 - Optional variant loader

Do not implement until phases 1-4 are stable.

Goal:

```gdscript
start_mode("spiral", "diamond_fireball_square")
```

or command line/project setting selects config path.

Checklist:

- [x] Keep `GameManager.start_mode("spiral")` working.
- [x] Add optional variant config path.
- [x] If variant is full config, load it directly.
- [x] If variant is partial override, implement deep merge carefully. (SKIP — variants are full copies)
- [x] Recording output path must include variant id.

**Implementation notes:** `GameManager.start_mode(mode_id, variant_id)` added optional second parameter. Derives path: `MODE_CONFIG_REGISTRY[mode_id].get_base_dir() + "/variants/" + variant_id + ".json"`. Falls back to default config if variant file not found (print warning). `start_mode("spiral")` unchanged — backward compatible.

---

## 7. Verification commands

Use available Godot command if installed:

```powershell
godot --headless --path . --quit
```

Manual visual checks:

1. Run default config.
2. Run one sprite variant.
3. Run square obstacle variant.
4. Run circle obstacle variant.
5. Watch first 30 seconds for tunneling/stuck behavior.

---

## 8. Stop conditions

Stop and ask user if:

1. Required scene node is missing and cannot be safely created.
2. Current config schema differs from this document in a breaking way.
3. Godot version errors on API names.
4. A requested visual change requires polygon collision.
5. Implementing filled channel would require large rewrite.
