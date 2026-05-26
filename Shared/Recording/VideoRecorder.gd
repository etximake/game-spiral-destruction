## VideoRecorder.gd
## Quay màn hình game qua FFmpeg.
## Tự động bắt đầu/dừng recording theo lifecycle simulation.
## Cấu hình: đặt trong config.json → "recording" section.
extends Node

# ── Config (từ GameManager) ───────────────────────────────────────────────────
var _enabled: bool = false
var _record_audio: bool = true
var _ffmpeg_path: String = "res://ffmpeg/bin/ffmpeg.exe"
var _output_path: String = "res://recordings/spiral_destruction.mp4"
var _fps: int = 60
var _scale_factor: float = 1.0
var _preset: String = "ultrafast"
var _crf: int = 23
var _auto_start: bool = true
var _auto_stop: bool = true
var _verbose: bool = true

var _viewport_w: int = 1080
var _viewport_h: int = 1920

# ── FFmpeg & Audio State ──────────────────────────────────────────────────────
var _ffmpeg_pid: int = 0
var _ffmpeg_pipe: FileAccess = null
var _last_error: String = ""
var _is_recording: bool = false
var _record_effect: AudioEffectRecord = null

# Đường dẫn tạm thời
var _current_temp_video: String = ""
var _current_temp_audio: String = ""
var _current_final_output: String = ""

# ── Multithread Queue ─────────────────────────────────────────────────────────
var _thread: Thread = Thread.new()
var _thread_active: bool = false
var _frame_queue: Array[Image] = []
var _queue_mutex: Mutex = Mutex.new()
var _queue_semaphore: Semaphore = Semaphore.new()

# ── Lifecycle ─────────────────────────────────────────────────────────────────
func _ready() -> void:
	# Cấu hình ghi âm Master Bus
	_setup_audio_recording()

	var bus = get_node_or_null("/root/EventBus")
	if bus:
		bus.simulation_ready.connect(_on_simulation_ready)
		if _auto_stop:
			bus.simulation_completed.connect(_on_simulation_completed)
			bus.simulation_stuck.connect(_on_simulation_stuck)
			bus.simulation_reset.connect(_on_simulation_reset)

func _on_simulation_ready(_mode_id: String) -> void:
	_load_config()
	if not _enabled:
		_log("VideoRecorder disabled in config")
		return

	# Lắng nghe Signal bắt đầu recording
	var bus = get_node_or_null("/root/EventBus")
	if bus and _auto_start and not bus.simulation_start_requested.is_connected(_on_simulation_start_requested):
		bus.simulation_start_requested.connect(_on_simulation_start_requested)

func _process(_delta: float) -> void:
	if not _enabled or not _is_recording:
		return
	_capture_frame()

func _exit_tree() -> void:
	if _is_recording:
		stop_recording()

# ── Public API ────────────────────────────────────────────────────────────────

## Bắt đầu ghi hình qua FFmpeg
func start_recording(timeout: float = -1.0) -> bool:
	if not _enabled:
		_log("Recording skipped (disabled)")
		return true

	if _is_recording:
		_log("Already recording")
		return true

	_load_config()

	# Đảm bảo thư mục lưu output tồn tại
	var global_output = ProjectSettings.globalize_path(_output_path)
	var output_dir = global_output.get_base_dir()
	if not DirAccess.dir_exists_absolute(output_dir):
		var err = DirAccess.make_dir_recursive_absolute(output_dir)
		if err != OK:
			_log("Failed to create directory: %s (err %d)" % [output_dir, err])
			return false

	# Định dạng tên file đầu ra chứa ngày giờ quay
	var ext = _output_path.get_extension()
	var base = _output_path.get_basename()
	var timestamp = Time.get_datetime_string_from_system().replace(":", "-").replace(" ", "_")
	
	_current_final_output = "%s_%s.%s" % [base, timestamp, ext]
	
	# Thiết lập đường dẫn tạm
	if _record_audio and _record_effect != null:
		_current_temp_video = "%s_temp_video_%s.mp4" % [base, timestamp]
		_current_temp_audio = "%s_temp_audio_%s.wav" % [base, timestamp]
	else:
		_current_temp_video = _current_final_output
		_current_temp_audio = ""

	var target_video_path = ProjectSettings.globalize_path(_current_temp_video)

	# Xóa file trùng cũ nếu có
	if FileAccess.file_exists(target_video_path):
		DirAccess.remove_absolute(target_video_path)

	# Lấy kích thước viewport thực tế
	var vp_size = get_viewport().size
	_viewport_w = vp_size.x
	_viewport_h = vp_size.y

	# Tính kích thước đích sau khi scale (đảm bảo chia hết cho 2 cho H.264)
	var target_w = int(_viewport_w * _scale_factor)
	var target_h = int(_viewport_h * _scale_factor)
	if target_w % 2 != 0: target_w += 1
	if target_h % 2 != 0: target_h += 1

	var global_ffmpeg = ProjectSettings.globalize_path(_ffmpeg_path)
	if not FileAccess.file_exists(global_ffmpeg):
		_last_error = "FFmpeg binary not found at: %s" % global_ffmpeg
		_log(_last_error)
		return false

	var args = PackedStringArray([
		"-y",
		"-f", "rawvideo",
		"-pix_fmt", "rgb24",
		"-s", "%dx%d" % [target_w, target_h],
		"-r", str(_fps),
		"-i", "-",
		"-c:v", "libx264",
		"-pix_fmt", "yuv420p",
		"-preset", _preset,
		"-crf", str(_crf),
		target_video_path
	])

	_log("Launching FFmpeg: %s %s" % [global_ffmpeg, " ".join(args)])

	var res = OS.execute_with_pipe(global_ffmpeg, args)
	if res.is_empty() or not res.has("stdio") or res["pid"] <= 0:
		_last_error = "Failed to launch FFmpeg process"
		_log(_last_error)
		return false

	_ffmpeg_pipe = res["stdio"]
	_ffmpeg_pid = res["pid"]
	_is_recording = true

	# Bật ghi âm
	if _record_audio and _record_effect != null:
		_record_effect.set_recording_active(true)
		_log("Audio recording enabled and active on Master bus.")

	# Reset queue & thread state
	_queue_mutex.lock()
	_frame_queue.clear()
	_queue_mutex.unlock()
	_thread_active = true

	var thread_err = _thread.start(_thread_loop)
	if thread_err != OK:
		_last_error = "Failed to start worker thread (err %d)" % thread_err
		_log(_last_error)
		_is_recording = false
		_ffmpeg_pipe.close()
		_ffmpeg_pipe = null
		if _ffmpeg_pid > 0:
			OS.kill(_ffmpeg_pid)
			_ffmpeg_pid = 0
		if _record_audio and _record_effect != null:
			_record_effect.set_recording_active(false)
		return false

	_log("Video recording started. Target: %dx%d @ %d FPS" % [target_w, target_h, _fps])
	return true

## Dừng ghi hình qua FFmpeg
func stop_recording(timeout: float = -1.0) -> bool:
	if not _is_recording:
		return true

	_log("Stopping recording. Draining %d frames..." % _frame_queue.size())
	_is_recording = false

	# Tắt ghi âm và lưu file wav
	var has_audio: bool = false
	if _record_audio and _record_effect != null:
		_record_effect.set_recording_active(false)
		var recording = _record_effect.get_recording()
		if recording:
			var global_audio_path = ProjectSettings.globalize_path(_current_temp_audio)
			var err = recording.save_to_wav(global_audio_path)
			if err == OK:
				has_audio = true
				_log("Saved audio to: %s" % _current_temp_audio)
			else:
				_log("Error saving audio file: %d" % err)

	# Tắt thread và đánh thức thread đang đợi semaphore
	_thread_active = false
	_queue_semaphore.post()

	# Chờ thread xử lý hết các frame trong hàng đợi và thoát
	if _thread.is_started():
		_thread.wait_to_finish()

	# Đóng pipe để FFmpeg kết thúc ghi file video
	if _ffmpeg_pipe != null:
		_ffmpeg_pipe.close()
		_ffmpeg_pipe = null

	# Chờ tiến trình FFmpeg thoát hẳn
	if _ffmpeg_pid > 0:
		var deadline = Time.get_ticks_msec() + 5000 # Chờ tối đa 5 giây
		while OS.is_process_running(_ffmpeg_pid) and Time.get_ticks_msec() < deadline:
			OS.delay_msec(50)

		if OS.is_process_running(_ffmpeg_pid):
			_log("FFmpeg process did not exit, killing it.")
			OS.kill(_ffmpeg_pid)
		else:
			_log("FFmpeg finished encoding video stream successfully.")
		_ffmpeg_pid = 0

	_queue_mutex.lock()
	_frame_queue.clear()
	_queue_mutex.unlock()

	# Tiến hành ghép (multiplex) âm thanh và video nếu có ghi âm
	if _record_audio and has_audio:
		_merge_audio_and_video()
	else:
		_log("Audio recording was skipped or failed. Output is silent video at: %s" % _current_final_output)

	_log("Video recording stopped.")
	return true

## Kiểm tra FFmpeg có sẵn sàng không
func is_available(timeout: float = -1.0) -> bool:
	_load_config()
	if not _enabled:
		return false
	var global_ffmpeg = ProjectSettings.globalize_path(_ffmpeg_path)
	if not FileAccess.file_exists(global_ffmpeg):
		_last_error = "FFmpeg binary not found at: %s" % global_ffmpeg
		return false
	return true

## Trả về true nếu đang ghi hình
func is_recording() -> bool:
	return _is_recording

# ── Signal Handlers (EventBus) ────────────────────────────────────────────────

func _on_simulation_start_requested(_mode_id: String) -> void:
	_log("Start simulation event -> start recording now")
	await start_recording()

func _on_simulation_completed(_mode_id: String, _duration: float) -> void:
	_log("Simulation completed -> auto stop recording")
	await stop_recording()

func _on_simulation_stuck(_mode_id: String, _radius: float) -> void:
	_log("Simulation stuck -> auto stop recording")
	await stop_recording()

func _on_simulation_reset() -> void:
	if _is_recording:
		_log("Simulation reset -> auto stop recording")
		await stop_recording()

# ── Capture and Thread Logic ──────────────────────────────────────────────────

func _capture_frame() -> void:
	var img = get_viewport().get_texture().get_image()
	if img == null or img.is_empty():
		return

	_queue_mutex.lock()
	if _frame_queue.size() < 180:
		_frame_queue.append(img)
	else:
		_log("Warning: Frame queue buffer overflow, dropping frame!")
	_queue_mutex.unlock()
	
	_queue_semaphore.post()

func _thread_loop() -> void:
	while _thread_active or not _frame_queue.is_empty():
		_queue_semaphore.wait()

		var img: Image = null
		_queue_mutex.lock()
		if not _frame_queue.is_empty():
			img = _frame_queue.pop_front()
		_queue_mutex.unlock()

		if img != null:
			_process_and_write_frame(img)

	_log("Worker thread exited.")

func _process_and_write_frame(img: Image) -> void:
	if _ffmpeg_pid > 0 and not OS.is_process_running(_ffmpeg_pid):
		_log("Error: FFmpeg process died unexpectedly!")
		_is_recording = false
		return

	if _scale_factor != 1.0:
		var target_w = int(_viewport_w * _scale_factor)
		var target_h = int(_viewport_h * _scale_factor)
		if target_w % 2 != 0: target_w += 1
		if target_h % 2 != 0: target_h += 1
		img.resize(target_w, target_h, Image.INTERPOLATE_BILINEAR)

	img.convert(Image.FORMAT_RGB8)
	var data = img.get_data()

	if _ffmpeg_pipe != null:
		_ffmpeg_pipe.store_buffer(data)

# ── Helpers ───────────────────────────────────────────────────────────────────

func _setup_audio_recording() -> void:
	var master_bus_idx = AudioServer.get_bus_index("Master")
	var found = false
	for i in AudioServer.get_bus_effect_count(master_bus_idx):
		if AudioServer.get_bus_effect(master_bus_idx, i) is AudioEffectRecord:
			_record_effect = AudioServer.get_bus_effect(master_bus_idx, i)
			found = true
			break
			
	if not found:
		_record_effect = AudioEffectRecord.new()
		AudioServer.add_bus_effect(master_bus_idx, _record_effect)
		_log("Added new AudioEffectRecord dynamically to Master bus.")

func _merge_audio_and_video() -> void:
	var global_ffmpeg = ProjectSettings.globalize_path(_ffmpeg_path)
	var global_temp_video = ProjectSettings.globalize_path(_current_temp_video)
	var global_temp_audio = ProjectSettings.globalize_path(_current_temp_audio)
	var global_final = ProjectSettings.globalize_path(_current_final_output)

	_log("Merging audio and video streams using FFmpeg...")
	
	# Command: ffmpeg -y -i temp_video.mp4 -i temp_audio.wav -c:v copy -c:a aac final.mp4
	var args = PackedStringArray([
		"-y",
		"-i", global_temp_video,
		"-i", global_temp_audio,
		"-c:v", "copy",
		"-c:a", "aac",
		global_final
	])

	var output = []
	var exit_code = OS.execute(global_ffmpeg, args, output, true)

	if exit_code == 0:
		_log("Successfully generated video with audio at: %s" % _current_final_output)
		# Xóa file tạm
		DirAccess.remove_absolute(global_temp_video)
		DirAccess.remove_absolute(global_temp_audio)
	else:
		_log("Error: FFmpeg merge failed! Exit code: %d" % exit_code)
		# Fallback: rename file video tạm thành file chính nếu ghép lỗi
		if FileAccess.file_exists(global_temp_video):
			var dir = DirAccess.open("res://")
			dir.rename(_current_temp_video, _current_final_output)
			_log("Fallback: preserved silent video output at: %s" % _current_final_output)
		if FileAccess.file_exists(global_temp_audio):
			DirAccess.remove_absolute(global_temp_audio)

func _load_config() -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.has_method("get_current_config"):
		var cfg: Dictionary = gm.get_current_config()
		var rec: Dictionary = cfg.get("recording", {})
		_enabled = rec.get("enabled", false)
		_record_audio = rec.get("record_audio", true)
		_ffmpeg_path = rec.get("ffmpeg_path", "res://ffmpeg/bin/ffmpeg.exe")
		_output_path = rec.get("output_path", "res://recordings/spiral_destruction.mp4")
		_fps = int(rec.get("fps", 60))
		_scale_factor = float(rec.get("scale_factor", 1.0))
		_preset = rec.get("preset", "ultrafast")
		_crf = int(rec.get("crf", 23))
		_auto_start = rec.get("auto_start", true)
		_auto_stop = rec.get("auto_stop", true)
		_verbose = rec.get("verbose", true)

		var vp: Dictionary = cfg.get("viewport", {})
		var res_arr: Array = vp.get("resolution", [])
		if res_arr.size() >= 2:
			_viewport_w = int(res_arr[0])
			_viewport_h = int(res_arr[1])

func _log(message: String) -> void:
	if not _verbose:
		return
	print("[VideoRecorder] %s" % message)
