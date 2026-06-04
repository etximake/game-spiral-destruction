# Prompt for DeepSeek AI Coding

**STATUS:** ✅ Implemented (2026-05-27). All 5 phases done.
📖 Usage guide: `USAGE_GUIDE.md`
📋 Checklist: `DEEPSEEK_IMPLEMENTATION_CHECKLIST.md`

Copy prompt nay vao DeepSeek khi muon no implement content variant system cho SpiralDestruction.

---

## Prompt

You are working in a Godot 4.5 project. The target mode is `Modes/SpiralDestruction`.

Before coding, read these files:

```text
docs/ARCHITECTURE.md
docs/CONFIG_SCHEMA.md
Modes/SpiralDestruction/designs/GDD_SpiralDestruction.md
Modes/SpiralDestruction/designs/CONTENT_VARIANTS_PLAN.md
Modes/SpiralDestruction/designs/BALL_SKIN_RESOURCE_DESIGN.md
Modes/SpiralDestruction/designs/OBSTACLE_SHAPE_VARIANTS_DESIGN.md
Modes/SpiralDestruction/designs/DEEPSEEK_IMPLEMENTATION_CHECKLIST.md
Modes/SpiralDestruction/config.json
Modes/SpiralDestruction/SpiralMode.gd
Modes/SpiralDestruction/Entities/Ball.gd
Modes/SpiralDestruction/Systems/SpiralMapController.gd
Modes/SpiralDestruction/Systems/SpiralRenderController.gd
```

Implement only the phase I ask for. Do not implement later phases unless explicitly requested.

Strict rules:

1. Do not rewrite whole files.
2. Do not refactor unrelated code.
3. Keep default `Modes/SpiralDestruction/config.json` working.
4. Keep backward compatibility with existing `triangles` config.
5. Do not replace custom physics with Godot physics.
6. Do not change CCD, spiral wall collision, stuck detection, or win condition unless explicitly requested.
7. Ball sprite skin is visual only; collision remains circle using `radius`.
8. Obstacle shape variants are visual mesh changes only in the first implementation; collision remains circle approximation.
9. Keep `MultiMeshInstance2D` for obstacles. Do not create one node per obstacle.
10. Every new config field must have a safe fallback default.
11. If an asset path is invalid, print a warning and fallback; do not crash.
12. After editing, run or describe the Godot compile check.

Implementation order:

1. Phase 1: add optional `content` config for title and target emoji.
2. Phase 2: add ball sprite skin support through `ball.visual`.
3. Phase 3: add obstacle shape support through `triangles.shape`.
4. Phase 4: create full config variant files in `Modes/SpiralDestruction/variants`.
5. Phase 5: optional variant loader only after phases 1-4 are stable.

When implementing a phase, follow `DEEPSEEK_IMPLEMENTATION_CHECKLIST.md` exactly. Show a short summary of files changed and tests run.

---

## Example request for Phase 1

Implement Phase 1 only: add optional `content` section support for `title` and `target_emoji`. Do not touch ball skin or obstacle shapes yet.

---

## Example request for Phase 2

Implement Phase 2 only: add `ball.visual` sprite support. Keep physics circle-based. Missing sprite path must fallback to mesh.

---

## Example request for Phase 3

Implement Phase 3 only: add `triangles.shape = triangle | square | circle` render support. Keep collision unchanged.

---

## Example request for Phase 4

Implement Phase 4 only: create full config variants under `Modes/SpiralDestruction/variants`. Do not add a variant loader yet.
