extends "res://tests/gut/base/qqt_contract_test.gd"

const PathScanHelperScript = preload("res://tests/helpers/contracts/path_scan_helper.gd")

const SCAN_ROOTS := [
	"res://app",
	"res://network",
	"res://scenes",
	"res://tests",
	"res://docs",
]
const EXCLUDED_PREFIXES := [
	"res://tests/archive/",
	"res://addons/",
	"res://docs/archive/",
]
const EXCLUDED_FILES := [
	"res://tests/contracts/path/no_legacy_test_runner_reference_contract_test.gd",
]
const LEGACY_RUNNER_REF := "res://tests/cli/run_test.gd"
const FILE_SUFFIXES := [".gd", ".md", ".txt", ".ps1", ".json"]


func test_no_legacy_runner_reference_in_repo() -> void:
	var violations: Array[String] = []
	for root in SCAN_ROOTS:
		var files := PathScanHelperScript.collect_files_recursive(root, "")
		for file_path in files:
			if _is_excluded(file_path) or not _is_scannable(file_path):
				continue
			if PathScanHelperScript.file_contains(file_path, LEGACY_RUNNER_REF):
				violations.append(file_path)
	assert_true(violations.is_empty(), "legacy test runner reference detected:\n%s" % "\n".join(violations))


func _is_excluded(path: String) -> bool:
	for prefix in EXCLUDED_PREFIXES:
		if path.begins_with(prefix):
			return true
	for file_path in EXCLUDED_FILES:
		if path == file_path:
			return true
	return false


func _is_scannable(path: String) -> bool:
	for suffix in FILE_SUFFIXES:
		if path.ends_with(suffix):
			return true
	return false
