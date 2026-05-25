## VideoRecorder.gd
## Module quay video — ghi lại màn hình gameplay.
## Chỉ ghi khi nhấn Space → game chạy, dừng khi game kết thúc.
##
## Yêu cầu: FFmpeg (https://ffmpeg.org/)
##   - Cách 1 (khuyên dùng): Copy ffmpeg.exe vào cùng thư mục file game
##   - Cách 2: Cài FFmpeg vào PATH
##   - Cách 3: Set đường dẫn trong config.json → recording.ffmpeg_path
##
## Cách dùng:
##   1. Mở game bình thường (không cần flag --write-movie)
##   2. Nhấn Space → tự động ghi hình window game
##   3. Game kết thúc → video lưu tại user://recordings/
extends Node

# ── Config ────────────────────────────────────────────────────────────────────
var _enabled: bool = true
var _show_indicator: bool = true
var _ffmpeg_path: String = "ffmpeg"
var _recording: bool = false
var _ffmpeg_available: bool = false
var _ffmpeg_pid: int = -1
var _output_path: String = ""

# ── Recording indicator UI ────────────────────────────────────────────────────
var _indicator: CanvasLayer = null
var _indicator_container: Control = null
var _indicator_dot: ColorRect = null
var _indicator_timer: float = 0.0

# ── Autoload shortcuts ────────────────────────────────────────────────────────
@onready var _event_bus: Node = get_node("/root/EventBus")

func _ready() -> void:
	_load_config()
	
	# Kiểm tra FFmpeg
	_ffmpeg_available = _check_ffmpeg()
	
	if _ffmpeg_available:
		# Tạo thư mục output
		DirAccess.make_dir_recursive_absolute("D:\\Tai lieu kenh algodoo\\game-spiral-destruction\\output")
		print("[VideoRecorder] ✅ FFmpeg available — chờ Space để ghi hình")
	else:
		print("[VideoRecorder] ❌ Không tìm thấy FFmpeg. Tải tại: https://ffmpeg.org/")
		print("[VideoRecorder]    Thêm ffmpeg.exe vào PATH, hoặc đặt cạnh file game.")
	
	# Tạo indicator
	if _show_indicator:
		_create_indicator()
	_update_indicator_visible(false)
	
	# Kết nối signal
	_event_bus.simulation_started.connect(_on_simulation_started)
	_event_bus.simulation_completed.connect(_on_simulation_completed)

func _load_config() -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.has_method("get_current_config"):
		var cfg: Dictionary = gm.get_current_config()
		var rec_cfg: Dictionary = cfg.get("recording", {})
		_enabled = rec_cfg.get("enabled", true)
		_show_indicator = rec_cfg.get("show_indicator", true)
		_ffmpeg_path = rec_cfg.get("ffmpeg_path", _ffmpeg_path)

func _process(delta: float) -> void:
	if not _recording or not _show_indicator or not is_instance_valid(_indicator):
		return
	# Nhấp nháy chấm đỏ
	_indicator_timer += delta
	var blink: float = sin(_indicator_timer * 4.0) * 0.5 + 0.5
	if is_instance_valid(_indicator_dot):
		_indicator_dot.modulate.a = 0.3 + blink * 0.7

# ── FFmpeg ────────────────────────────────────────────────────────────────────

func _check_ffmpeg() -> bool:
	var output: Array = []

	# Helper: kiểm tra file tồn tại rồi mới execute (tránh warning)
	var _try_exec := func(path: String) -> bool:
		if not FileAccess.file_exists(path):
			return false
		return OS.execute(path, ["-version"], output, true) == 0

	# 1. ffmpeg/bin/ffmpeg.exe trong thư mục project (res://ffmpeg/bin/)
	var project_ffmpeg_bin: String = ProjectSettings.globalize_path("res://ffmpeg/bin/ffmpeg.exe")
	if _try_exec.call(project_ffmpeg_bin):
		_ffmpeg_path = project_ffmpeg_bin
		return true
	# 2. ffmpeg.exe trong thư mục project Godot (res://)
	var project_ffmpeg: String = ProjectSettings.globalize_path("res://ffmpeg.exe")
	if _try_exec.call(project_ffmpeg):
		_ffmpeg_path = project_ffmpeg
		return true
	# 3. ffmpeg.exe cạnh file game (bundle)
	var game_dir: String = OS.get_executable_path().get_base_dir()
	var bundled: String = game_dir.path_join("ffmpeg.exe")
	if _try_exec.call(bundled):
		_ffmpeg_path = bundled
		return true
	# 4. Đường dẫn từ config
	if _try_exec.call(_ffmpeg_path):
		return true
	# 5. C:\ffmpeg\ffmpeg.exe (thư mục gốc, không có bin)
	if _try_exec.call("C:\\ffmpeg\\ffmpeg.exe"):
		_ffmpeg_path = "C:\\ffmpeg\\ffmpeg.exe"
		return true
	# 6. ffmpeg trong PATH
	if OS.execute("ffmpeg", ["-version"], output, true) == 0:
		_ffmpeg_path = "ffmpeg"
		return true
	# 7. Đường dẫn cứng C:\ffmpeg\bin
	if _try_exec.call("C:\\ffmpeg\\bin\\ffmpeg.exe"):
		_ffmpeg_path = "C:\\ffmpeg\\bin\\ffmpeg.exe"
		return true
	return false

func _start_recording() -> void:
	if _recording:
		return

	# Load lại config (lúc này GameManager đã có config thật)
	_load_config()
	# Kiểm tra lại FFmpeg với config mới
	if not _check_ffmpeg():
		push_error("[VideoRecorder] ❌ Không thể khởi động FFmpeg!")
		push_error("[VideoRecorder]    Kiểm tra: %s" % _ffmpeg_path)
		return
	
	# Tạo tên file theo timestamp
	var timestamp: String = Time.get_datetime_string_from_system().replace(":", "-").replace(" ", "_")
	var output_dir: String = "D:\\Tai lieu kenh algodoo\\game-spiral-destruction\\output"
	DirAccess.make_dir_recursive_absolute(output_dir)
	_output_path = "%s\\gameplay_%s.mp4" % [output_dir, timestamp]
	
	# Lấy tên window game (set từ project.godot: config/name)
	var window_title: String = ProjectSettings.get_setting("application/config/name", "game-spiral-destruction")

	# Build command — tất cả path có spaces đều phải quote
	var cmd_line: String = '"%s" -f gdigrab -framerate 60 -i "title=%s" -c:v libx264 -preset ultrafast -crf 23 -pix_fmt yuv420p -y "%s"' % [_ffmpeg_path, window_title, _output_path]
	print("[VideoRecorder] CMD: %s" % cmd_line)
	var shell_args: PackedStringArray = ["/c", "start", "/B", "" , cmd_line]
	_ffmpeg_pid = OS.execute("cmd", shell_args, [], false)

	if _ffmpeg_pid > 0:
		_recording = true
		print("[VideoRecorder] ▶️ Ghi hình: %s" % _output_path)
		_update_indicator_visible(true)
		set_process(true)
	else:
		push_error("[VideoRecorder] ❌ Không thể khởi động FFmpeg!")
		push_error("[VideoRecorder]    Kiểm tra: %s" % _ffmpeg_path)

func _stop_recording() -> void:
	if not _recording:
		return
	
	# Kill FFmpeg bằng tên process (vì PID là của cmd.exe, không phải ffmpeg)
	if DisplayServer.get_name() == "Windows":
		OS.execute("taskkill", ["/IM", "ffmpeg.exe", "/F"], [], false)
	elif _ffmpeg_pid > 0:
		OS.kill(_ffmpeg_pid)
	
	_ffmpeg_pid = -1
	_recording = false
	print("[VideoRecorder] ⏹ Đã lưu video: %s" % _output_path)
	_update_indicator_visible(false)
	set_process(false)

# ── Signal handlers ───────────────────────────────────────────────────────────

func _on_simulation_started(_mode_id: String) -> void:
	if not _enabled:
		return
	_start_recording()

func _on_simulation_completed(_mode_id: String, _duration: float) -> void:
	if not _enabled:
		return
	_stop_recording()

func _exit_tree() -> void:
	# Dọn dẹp khi scene bị huỷ
	if _recording:
		_stop_recording()

# ── UI Indicator ──────────────────────────────────────────────────────────────

func _create_indicator() -> void:
	_indicator = CanvasLayer.new()
	_indicator.name = "RecCanvas"
	_indicator.layer = 100
	
	var container := Control.new()
	container.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 10)
	container.custom_minimum_size = Vector2(60, 20)
	_indicator_container = container
	
	# Chấm đỏ
	_indicator_dot = ColorRect.new()
	_indicator_dot.color = Color(1.0, 0.1, 0.05, 0.9)
	_indicator_dot.size = Vector2(10, 10)
	_indicator_dot.position = Vector2(3, 5)
	container.add_child(_indicator_dot)
	
	# Label REC
	var label := Label.new()
	label.text = "REC"
	label.add_theme_color_override("font_color", Color.RED)
	label.add_theme_font_size_override("font_size", 14)
	label.position = Vector2(16, 2)
	container.add_child(label)
	
	_indicator.add_child(container)
	get_tree().root.add_child.call_deferred(_indicator)

func _update_indicator_visible(visible: bool) -> void:
	if is_instance_valid(_indicator):
		_indicator.visible = visible
