extends "res://tests/gut/base/qqt_contract_test.gd"

const PathScanHelperScript = preload("res://tests/helpers/contracts/path_scan_helper.gd")

const SCAN_ROOTS := [
	"res://app/front/",
	"res://network/runtime/",
	"res://network/session/runtime/",
]
const EXCLUDED_PREFIXES := [
	"res://app/infra/http/",
	"res://tests/",
]
const FORBIDDEN_PATTERN := "HTTPClient.new()"


func test_no_direct_httpclient_new_in_runtime_paths() -> void:
	var files: Array[String] = []
	for root in SCAN_ROOTS:
		var collected := PathScanHelperScript.collect_files_recursive(root, ".gd")
		for file_path in collected:
			var excluded := false
			for prefix in EXCLUDED_PREFIXES:
				if file_path.begins_with(prefix):
					excluded = true
					break
			if excluded:
				continue
			files.append(file_path)
	var violations: Array[String] = []
	for file_path in files:
		if PathScanHelperScript.file_contains(file_path, FORBIDDEN_PATTERN):
			violations.append(file_path)
	assert_true(violations.is_empty(), "forbidden HTTPClient direct construction detected:\n%s" % "\n".join(violations))
