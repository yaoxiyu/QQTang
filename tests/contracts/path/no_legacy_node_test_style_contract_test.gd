extends "res://tests/gut/base/qqt_contract_test.gd"

const PathScanHelperScript = preload("res://tests/helpers/contracts/path_scan_helper.gd")

const TEST_ROOT := "res://tests"
const EXCLUDED_PREFIXES := [
	"res://tests/helpers/",
	"res://tests/archive/",
	"res://tests/gut/base/",
]
const EXCLUDED_FILES := [
	"res://tests/contracts/path/no_legacy_node_test_style_contract_test.gd",
]
const FORBIDDEN_PATTERNS := [
	"extends Node",
	"func _ready(",
	"signal test_finished",
	"TestAssert.is_true",
]


func test_no_legacy_node_test_style_in_test_files() -> void:
	var files := PathScanHelperScript.collect_files_recursive(TEST_ROOT, "_test.gd")
	var violations: Array[String] = []
	for file_path in files:
		if _is_excluded(file_path):
			continue
		var text := _read_text(file_path)
		for pattern in FORBIDDEN_PATTERNS:
			if text.find(pattern) >= 0:
				violations.append("%s -> %s" % [file_path, pattern])
		var lines := text.split("\n")
		for line in lines:
			if line.find("print(") >= 0 and line.find("PASS") >= 0:
				violations.append("%s -> print PASS line" % file_path)
			if line.find("push_error(") >= 0 and line.find("FAIL") >= 0:
				violations.append("%s -> push_error FAIL line" % file_path)
	assert_true(violations.is_empty(), "legacy node style patterns found:\n%s" % "\n".join(violations))


func _is_excluded(path: String) -> bool:
	for prefix in EXCLUDED_PREFIXES:
		if path.begins_with(prefix):
			return true
	for file_path in EXCLUDED_FILES:
		if path == file_path:
			return true
	return false


func _read_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	return file.get_as_text()
