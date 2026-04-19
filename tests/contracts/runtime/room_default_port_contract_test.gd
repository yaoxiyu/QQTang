extends "res://tests/gut/base/qqt_contract_test.gd"

const ROOM_SERVICE_BOOTSTRAP_PATH := "res://network/runtime/legacy/room_service_bootstrap.gd"
const CLIENT_ROOM_RUNTIME_PATH := "res://network/runtime/room_client/client_room_runtime.gd"
const LOBBY_USE_CASE_PATH := "res://app/front/lobby/lobby_use_case.gd"
const LOBBY_DIRECTORY_USE_CASE_PATH := "res://app/front/lobby/lobby_directory_use_case.gd"
const FRONT_SETTINGS_STATE_PATH := "res://app/front/profile/front_settings_state.gd"
const ROOM_SERVICE_CONTRACT_DOC_PATH := "res://docs/platform_room/room_service_runtime_contract.md"


func test_room_default_port_contract() -> void:
	_assert_contains(ROOM_SERVICE_CONTRACT_DOC_PATH, "Default listen port: `9100`")
	_assert_contains(ROOM_SERVICE_BOOTSTRAP_PATH, "@export var listen_port: int = 9100")
	_assert_contains(CLIENT_ROOM_RUNTIME_PATH, "else 9100")
	_assert_not_contains(CLIENT_ROOM_RUNTIME_PATH, "else 9000")
	_assert_contains(LOBBY_USE_CASE_PATH, "return 9100")
	_assert_not_contains(LOBBY_USE_CASE_PATH, "return 9000")
	_assert_contains(LOBBY_DIRECTORY_USE_CASE_PATH, "return 9100")
	_assert_not_contains(LOBBY_DIRECTORY_USE_CASE_PATH, "return 9000")
	_assert_contains(FRONT_SETTINGS_STATE_PATH, "var last_server_port: int = 9100")
	_assert_not_contains(FRONT_SETTINGS_STATE_PATH, "last_server_port = 9000")


func _assert_contains(path: String, pattern: String) -> void:
	var text := _read_text(path)
	assert_false(text.is_empty(), "file should be readable: %s" % path)
	if text.is_empty():
		return
	assert_true(text.find(pattern) >= 0, "expected pattern missing in %s: %s" % [path, pattern])


func _assert_not_contains(path: String, pattern: String) -> void:
	var text := _read_text(path)
	assert_false(text.is_empty(), "file should be readable: %s" % path)
	if text.is_empty():
		return
	assert_true(text.find(pattern) < 0, "unexpected pattern found in %s: %s" % [path, pattern])


func _read_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	return file.get_as_text()
