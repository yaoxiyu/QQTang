extends "res://tests/gut/base/qqt_contract_test.gd"

const REQUIRED_PATHS := [
	"res://network/session/battle_session_bootstrap.gd",
	"res://network/session/battle_session_network_gateway.gd",
	"res://network/session/runtime/client_runtime_snapshot_applier.gd",
	"res://network/session/runtime/client_runtime_resume_coordinator.gd",
	"res://network/session/runtime/client_runtime_metrics_collector.gd",
	"res://scenes/battle/battle_flow_coordinator.gd",
	"res://scenes/battle/battle_result_transition_controller.gd",
]
const LINE_LIMITS := {
	"res://network/session/battle_session_adapter.gd": 700,
	"res://network/session/runtime/client_runtime.gd": 650,
	"res://scenes/battle/battle_main_controller.gd": 600,
}


func test_wp11_required_collaborators_exist() -> void:
	for path in REQUIRED_PATHS:
		assert_true(FileAccess.file_exists(path), "%s should exist" % path)


func test_wp11_line_boundaries_hold_for_completed_slices() -> void:
	for path in LINE_LIMITS.keys():
		var text := _read_text(path)
		assert_false(text.is_empty(), "%s should be readable" % path)
		assert_true(_line_count(text) <= int(LINE_LIMITS[path]), "%s should stay <= %d lines" % [path, int(LINE_LIMITS[path])])


func _read_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	return file.get_as_text()


func _line_count(text: String) -> int:
	if text.is_empty():
		return 0
	return text.split("\n").size()
