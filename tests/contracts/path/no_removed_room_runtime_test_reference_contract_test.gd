extends "res://tests/gut/base/qqt_contract_test.gd"

const PathScanHelperScript = preload("res://tests/helpers/contracts/path_scan_helper.gd")

const TEST_ROOT := "res://tests"
const EXCLUDED_FILES := [
	"res://tests/contracts/path/no_removed_room_runtime_test_reference_contract_test.gd",
	"res://tests/contracts/path/canonical_path_contract_test.gd",
	"res://tests/contracts/path/no_legacy_compat_assets_contract_test.gd",
	"res://tests/contracts/path/no_legacy_runtime_bridge_contract_test.gd",
]
const FORBIDDEN_PATTERNS := [
	"res://network/runtime/legacy/",
	"res://network/session/legacy/",
	"res://network/runtime/dedicated_server_bootstrap.gd",
	"res://network/session/runtime/server_room_runtime.gd",
	"res://network/session/runtime/server_room_runtime_compat_impl.gd",
	"res://network/session/runtime/legacy_room_runtime_bridge.gd",
]


func test_no_removed_room_runtime_references_in_tests() -> void:
	var files := PathScanHelperScript.collect_files_recursive(TEST_ROOT, ".gd")
	var violations: Array[String] = []
	for file_path in files:
		if _is_excluded(file_path):
			continue
		var text := _read_text(file_path)
		for pattern in FORBIDDEN_PATTERNS:
			if text.find(pattern) >= 0:
				violations.append("%s -> %s" % [file_path, pattern])
	assert_true(
		violations.is_empty(),
		"removed room runtime reference detected:\n%s" % "\n".join(violations)
	)


func _is_excluded(path: String) -> bool:
	for file_path in EXCLUDED_FILES:
		if path == file_path:
			return true
	return false


func _read_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	return file.get_as_text()
