extends "res://tests/gut/base/qqt_contract_test.gd"

const APP_RUNTIME_ROOT_PATH := "res://app/flow/app_runtime_root.gd"
const MAX_APP_RUNTIME_ROOT_LINES := 450
const FORBIDDEN_PATTERNS := [
	"AppRuntimeServicesScript",
	"RoomSessionControllerScript",
	"MatchStartCoordinatorScript",
	"BattleSessionAdapterScript",
	"ClientRoomRuntimeScript",
	"func _ensure_front_services(",
	"func _ensure_front_use_cases(",
	"func _get_battle_root_child_names(",
]


func test_app_runtime_root_stays_within_boundary() -> void:
	var text := _read_text(APP_RUNTIME_ROOT_PATH)
	assert_false(text.is_empty(), "app_runtime_root.gd should be readable")
	assert_true(_line_count(text) <= MAX_APP_RUNTIME_ROOT_LINES, "app_runtime_root.gd should stay <= %d lines" % MAX_APP_RUNTIME_ROOT_LINES)

	var violations: Array[String] = []
	for pattern in FORBIDDEN_PATTERNS:
		if text.find(pattern) >= 0:
			violations.append(pattern)
	assert_true(violations.is_empty(), "app_runtime_root.gd boundary violations:\n%s" % "\n".join(violations))


func _read_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	return file.get_as_text()


func _line_count(text: String) -> int:
	if text.is_empty():
		return 0
	return text.split("\n").size()
