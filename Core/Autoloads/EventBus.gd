## EventBus.gd
## Singleton — Observer Pattern thuần túy.
## Không chứa logic, chỉ khai báo signals toàn cục.
## Mọi hệ thống giao tiếp qua đây để đảm bảo Decoupling hoàn toàn.
extends Node

# ── Simulation lifecycle ──────────────────────────────────────────────────────
## Phát khi một simulation mode bắt đầu chạy
signal simulation_started(mode_id: String)

## Phát khi simulation kết thúc (win condition đạt được)
signal simulation_completed(mode_id: String, duration: float)

## Phát khi reset về trạng thái ban đầu
signal simulation_reset()

# ── Brick / Triangle events ───────────────────────────────────────────────────
## Phát khi một tam giác bị phá hủy
## brick_id: index trong MultiMesh
## world_position: vị trí thế giới để spawn particles
## color: màu của tam giác (dùng cho debris particles)
signal brick_destroyed(brick_id: int, world_position: Vector2, color: Color)

# ── Ball events ───────────────────────────────────────────────────────────────
## Phát khi bóng nảy vào tường spiral
## position: điểm va chạm
## normal: pháp tuyến tại điểm va chạm
signal ball_bounced(position: Vector2, normal: Vector2)

## Phát khi bán kính bóng thay đổi (để HUD cập nhật)
signal ball_radius_changed(new_radius: float)

# ── HUD events ────────────────────────────────────────────────────────────────
## Phát để yêu cầu HUD cập nhật một giá trị bất kỳ
## key: tên trường ("radius", "destroyed", "timer")
## value: giá trị mới (Variant để linh hoạt)
signal hud_update_requested(key: String, value: Variant)
