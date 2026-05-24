# SYSTEM INSTRUCTIONS & CONTEXT FOR CODING ASSISTANT

You are an expert Godot 4.5 GDScript game developer and system architect. You are assisting in developing the **Geometric Destruction Sandbox** project. Read and internalize the context, rules, and guidelines below before making any changes.

---

## 1. Project Overview & Philosophy
- **Purpose:** A sandbox engine in Godot 4.5 (Mobile renderer, 1080x1920 viewport) designed to run **automated, oddly-satisfying simulation videos** for YouTube Shorts and TikTok (9:16 aspect ratio). It behaves like a camera/recorder, not an interactive game.
- **Zero GC Runtime:** No new object instances during simulation run. Pre-allocate or reuse pools (e.g., `ObjectPool`).
- **1 Draw Call Geometry:** Static elements render via `MultiMeshInstance2D`.
- **Decoupled Architecture:** Communication strictly event-driven via `EventBus`.
- **Config-Driven (v2.0):** All mode parameters are in `configs/{mode_id}.json`, not hardcoded. Users customize by editing JSON, not code.

---

## 2. Codebase Structure
- **Config:** `Modes/SpiralDestruction/config.json` — All mode parameters in the mode's own folder.
- **Config Loader:** `Core/Base/ModeConfigLoader.gd` — Parses and validates JSON configs.
- **Core:** `Core/GameScene.tscn`, `Core/Autoloads/GameManager.gd` (config registry + state machine), `EventBus.gd`, `ObjectPool.gd`.
- **Mode coordinator:** `Modes/SpiralDestruction/SpiralMode.gd` — Controls simulation, auto-test, transitions.
- **Systems:** `SpiralMapController.gd` (spiral geometry + spatial grid), `SpiralRenderController.gd` (MultiMesh + Line2D rendering).
- **Entities:** `Ball.gd` — Custom physics (CCD, trail, collision).
- **Shared Effects:** `GlassDebris.gd`, `DopamineEmojiExplosion.gd`, `ScreenShake.gd`.

---

## 3. Config-Driven Architecture
```
configs/spiral_destruction.json
    ↓ ModeConfigLoader.parse()
GameManager.start_mode("spiral")
    ↓ set_config(config) → setup() → start()
SpiralMode._config (Dictionary)
    ↓ truyền xuống subsystems
MapController.set_config()  → đọc spiral.*, triangles.*
RenderController.set_config() → đọc triangles.mesh.*, spiral.line_*
```

Key config sections: `meta`, `spiral`, `triangles`, `ball`, `auto_test`, `debris`, `win_effect`, `spatial_grid`, `audio`, `hud`.

### Current Auto-Test Radii & Speeds (from config):
```json
"tests": [
  { "radius": 45.0, "speed": 320.0 },
  { "radius": 38.0, "speed": 390.0 },
  { "radius": 25.0, "speed": 470.0 },
  { "radius": 17.0, "speed": 560.0 },
  { "radius": 12.0, "speed": 680.0 }
]
```

### Win Condition:
```gdscript
# Ball reaches SPIRAL_CENTER (emoji position)
global_position.distance_to(SPIRAL_CENTER) < WIN_DISTANCE + radius
# AND segment_idx >= spiral_points.size() - 60 (final segments only)
```

---
   - **Tunneling Prevention (Crucial):** The collision normal calculation in `get_spiral_wall_info` takes `old_pos`. The normal must always be oriented towards `old_pos` to ensure the ball is pushed back to the side it came from:
     ```gdscript
     if normal.dot(to_old) < 0.0:
         normal = -normal
     ```
    - **Sliding Physics:** Velocity must slide along the wall tangent rather than bouncing: `velocity = velocity.slide(normal).normalized() * ball_speed`.
    - **Bounce Event Cooldown:** Sound and screen shake signals must only emit on actual high-speed wall hits (`velocity.dot(normal) < -10.0`), not during continuous sliding.

---

## 4. Visual Layout & Render Order (Z-Index)
Strict ordering must be maintained to keep rendering clean:
- **Ball & Trail (Z = 2, Top):** The ball and its trail must draw on top of everything. The trail has `top_level = true` so its global points align correctly with the ball's trajectory, and is configured with `antialiased = true`, `joint_mode = LINE_JOINT_ROUND`, and round cap modes to taper into a smooth pointy triangle.
- **Emoji Target (Z = 1, Middle):** Drawn in front of the spiral line/triangles, but behind the ball.
- **Spiral Line & Triangles (Z = 0, Background):** Base geometry of the map.
- **Boundary Clashing Prevention:**
  - The spiral line stops generating points when the radius $r < 65.0\text{ px}$ from the center.
  - Triangle placement skips generating points within $r < 80.0\text{ px}$ of the center.
  - This creates a clean boundary around the emoji target; nothing overlaps or draws over it.

---

## 5. Dynamic Triangle Generation Rules
In [SpiralMapController.gd](file:///d:/Tai%20lieu%20kenh%20algodoo/game-spiral-destruction/Modes/SpiralDestruction/Systems/SpiralMapController.gd), triangles must occupy almost the entire width of the spiral channel:
1. **Dynamic Size Scaling:** The maximum size a triangle can have before clipping the inner wall of the channel is calculated as:
   `max_possible_size = (local_gap - TRIANGLE_GAP) / 0.866`
   The size is scaled to **95%** of this limit: `size = clamp(max_possible_size * 0.95, 24.0, 150.0)`.
2. **Dynamic Angular Spacing:** To prevent circumferential overlaps as they scale, the angular increment step `theta` is calculated dynamically based on the current triangle's size and radius:
   `var step = (size * 1.15) / r` (clamped to a minimum of `TRIANGLE_ANGLE_STEP` to ensure safety).
3. **Centroid Alignment:** The triangle centroid position is calculated using the equilateral triangle centroid offset:
   `pos = spiral_pos + to_center * (TRIANGLE_GAP + size * 0.289)`.
4. **Arched-Base Geometry:** The triangle mesh is generated as a 6-vertex fan-triangulated shield shape with a concave base curved parallel to the spiral wall (e.g. using a curvature center of `y = -1.8` in local coordinates). This pulls the base corners inwards to follow the spiral walls perfectly and avoid premature wall collisions.

---

## 6. Auto-Test Suite Progression & Win Condition
The game contains an automatic test suite comprising 5 sequential tests with varying ball sizes:
- **Radii & Speed Lists:**
  - Radii: `[62.0, 52.0, 42.0, 27.0, 15.0]`
  - Speeds: `[320.0, 390.0, 470.0, 560.0, 680.0]` (ball speed increases progressively across later tests).
- **Progression Logic:**
  - **Runs 1 to 4:** The ball diameter is too large to fit in the tapering inner turns of the spiral. The ball must get stuck (`❌ STUCK`) and trigger the next run.
  - **Run 5:** The ball has radius `15.0` (diameter `30.0`), which is smaller than `SPIRAL_GAP_MIN = 35.0`. It must successfully navigate all the way to the center, touch the emoji, and win (`✅ WIN`).
- **Ball Shrinkage:** The ball's radius must **NOT** shrink during the auto-test run (`shrink_enabled = false`).
- **Stuck Detection:** Triggers a transition if:
  - The ball does not progress closer to the center for `3.0 seconds` (active only after the first `5` bounces to let the ball start).
  - The total stage timer exceeds `20.0 seconds` (GDD timeout).
  - The ball flies out of bounds (`current_dist > outer_radius * 1.5 + 50.0`).
- **Win Condition Checks:**
  To prevent premature win triggers when a large ball passes near the center from an outer winding:
  1. The closest wall segment index must be at the end of the spiral (`segment_index >= spiral_points.size() - 60`).
  2. The ball diameter must physically fit the narrowest gap (`radius * 2.0 <= SPIRAL_GAP_MIN + 2.0`).
