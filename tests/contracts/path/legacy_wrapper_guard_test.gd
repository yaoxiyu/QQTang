extends Node

const LEGACY_SESSION_PREFIX := "res://gameplay/network/session/"
const SCAN_ROOTS := [
	"res://app",
	"res://network",
	"res://scenes",
	"res://presentation",
	"res://content",
	"res://gameplay",
]

const EXCLUDED_PREFIXES := [
	"res://gameplay/network/session/",
	"res://tests/",
	"res://docs/",
]


func _ready() -> void:
	run_all()


func run_all() -> void:
	var violations := _find_legacy_session_references()
	_assert_true(violations.is_empty(), "business code does not reference legacy gameplay/network/session wrappers\n%s" % "\n".join(violations))


func _find_legacy_session_references() -> Array[String]:
	var violations: Array[String] = []
	for root_path in SCAN_ROOTS:
		_scan_path(root_path, violations)
	return violations


func _scan_path(path: String, violations: Array[String]) -> void:
	if _is_excluded(path):
		return
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for directory_name in dir.get_directories():
		_scan_path(path.path_join(directory_name), violations)
	for file_name in dir.get_files():
		var file_path := path.path_join(file_name)
		if _is_excluded(file_path):
			continue
		if not (file_path.ends_with(".gd") or file_path.ends_with(".tscn") or file_path.ends_with(".tres")):
			continue
		var text := _read_text(file_path)
		if text.contains(LEGACY_SESSION_PREFIX):
			violations.append(file_path)


func _is_excluded(path: String) -> bool:
	for prefix in EXCLUDED_PREFIXES:
		if path.begins_with(prefix):
			return true
	return false


func _read_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var text := file.get_as_text()
	file.close()
	return text


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		print("[PASS] %s" % message)
		return
	push_error("[FAIL] %s" % message)
