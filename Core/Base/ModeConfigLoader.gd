## ModeConfigLoader.gd
## Load và validate JSON config cho mọi Simulation Mode.
## Mỗi mode có 1 file .json trong thư mục configs/.
## Core engine gọi loader để parse → validate → trả về Dictionary.
class_name ModeConfigLoader
extends RefCounted

var last_error: String = ""

# ── Schema mặc định (dùng làm fallback khi JSON thiếu field) ─────────────────
const DEFAULT_CONFIG: Dictionary = {
	"meta": {
		"mode_id": "",
		"name": "Unnamed Mode",
		"version": "1.0",
		"description": "",
		"scene_path": ""
	},
	"viewport": {
		"resolution": [1080, 1920],
		"background_color": "#000000"
	},
	"spatial_grid": {
		"cell_size": 100.0
	},
	"audio": {
		"pool_size": 16,
		"pitch_initial": 1.0,
		"pitch_increment": 0.03,
		"pitch_min": 0.8,
		"pitch_max": 2.5,
		"pitch_reset_delay": 2.0,
		"pitch_variation": 0.1
	}
}

## Fields bắt buộc phải có trong JSON (cấu trúc dotted: "meta.mode_id")
const REQUIRED_FIELDS: PackedStringArray = [
	"meta.mode_id",
	"meta.scene_path",
]

# ── Public API ────────────────────────────────────────────────────────────────

## Load config từ file JSON.
## path: đường dẫn resource (res://configs/xxx.json)
## Trả về Dictionary chứa config, hoặc null nếu lỗi.
func load_config(path: String) -> Dictionary:
	last_error = ""
	
	# 1. Kiểm tra file tồn tại
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		last_error = "Không thể mở file config: %s" % path
		return {}
	
	# 2. Parse JSON
	var content: String = file.get_as_text()
	file.close()
	
	var json := JSON.new()
	var parse_err := json.parse(content)
	if parse_err != OK:
		last_error = "Lỗi parse JSON tại dòng %d: %s" % [json.get_error_line(), json.get_error_message()]
		return {}
	
	var data: Dictionary = json.data
	if typeof(data) != TYPE_DICTIONARY:
		last_error = "Config phải là một JSON object (dict)"
		return {}
	
	# 3. Validate
	if not _validate(data):
		return {}
	
	# 4. Merge với defaults (điền field thiếu)
	var merged := _merge_defaults(data, DEFAULT_CONFIG)
	
	return merged

## Lấy mode_id từ file config mà không load toàn bộ (dùng cho registry)
func peek_mode_id(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var content: String = file.get_as_text()
	file.close()
	
	var json := JSON.new()
	if json.parse(content) != OK:
		return ""
	var data: Dictionary = json.data
	if data.has("meta") and typeof(data.meta) == TYPE_DICTIONARY and data.meta.has("mode_id"):
		return str(data.meta.mode_id)
	return ""

# ── Validation ───────────────────────────────────────────────────────────────

func _validate(data: Dictionary) -> bool:
	# Check required fields
	for field: String in REQUIRED_FIELDS:
		var parts: PackedStringArray = field.split(".")
		var current = data
		var found := true
		for part: String in parts:
			if current is Dictionary and current.has(part):
				current = current[part]
			else:
				found = false
				break
		if not found:
			last_error = "Thiếu field bắt buộc: '%s'" % field
			return false
	
	# Validate meta
	if not _validate_meta(data.meta):
		return false
	
	# Validate tests nếu có (auto_test)
	if data.has("auto_test") and data.auto_test is Dictionary:
		if data.auto_test.has("tests") and data.auto_test.tests is Array:
			if data.auto_test.tests.is_empty():
				last_error = "auto_test.tests không được rỗng"
				return false
	
	return true

func _validate_meta(meta: Dictionary) -> bool:
	if typeof(meta.mode_id) != TYPE_STRING or meta.mode_id.is_empty():
		last_error = "meta.mode_id phải là string không rỗng"
		return false
	if typeof(meta.scene_path) != TYPE_STRING or meta.scene_path.is_empty():
		last_error = "meta.scene_path phải là string không rỗng"
		return false
	# scene_path phải bắt đầu bằng res://
	if not meta.scene_path.begins_with("res://"):
		last_error = "meta.scene_path phải bắt đầu bằng 'res://'. Giá trị hiện tại: %s" % meta.scene_path
		return false
	# Kiểm tra file scene tồn tại
	if not ResourceLoader.exists(meta.scene_path):
		last_error = "Không tìm thấy scene: %s" % meta.scene_path
		return false
	return true

# ── Merge defaults ───────────────────────────────────────────────────────────

## Đệ quy merge data từ JSON vào default — giữ giá trị từ JSON, chỉ điền thiếu
func _merge_defaults(data: Dictionary, defaults: Dictionary) -> Dictionary:
	var result: Dictionary = data.duplicate()
	for key: Variant in defaults.keys():
		var key_s: String = str(key)
		if not result.has(key_s):
			result[key_s] = defaults[key_s]
		elif typeof(result[key_s]) == TYPE_DICTIONARY and typeof(defaults[key_s]) == TYPE_DICTIONARY:
			result[key_s] = _merge_defaults(result[key_s], defaults[key_s])
	return result

## Helper: Lấy config con theo đường dẫn dotted (vd: "spiral.center")
func get_subconfig(config: Dictionary, dotted_path: String, default_value: Variant = null) -> Variant:
	var parts: PackedStringArray = dotted_path.split(".")
	var current = config
	for part: String in parts:
		if current is Dictionary and current.has(part):
			current = current[part]
		else:
			return default_value
	return current

## Helper: Chuyển mảng [r, g, b] hoặc [r, g, b, a] thành Color
func array_to_color(arr: Array, default_color: Color = Color.WHITE) -> Color:
	if arr.size() < 3:
		return default_color
	if arr.size() == 3:
		return Color(arr[0], arr[1], arr[2])
	return Color(arr[0], arr[1], arr[2], arr[3])

## Helper: Chuyển mảng [x, y] thành Vector2
func array_to_vector2(arr: Array, default_vec: Vector2 = Vector2.ZERO) -> Vector2:
	if arr.size() < 2:
		return default_vec
	return Vector2(arr[0], arr[1])
