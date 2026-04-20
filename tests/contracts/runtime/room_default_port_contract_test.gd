extends "res://tests/gut/base/qqt_contract_test.gd"

const ROOM_SERVICE_ENV_EXAMPLE_PATH := "res://services/room_service/.env.example"
const ROOM_DEFAULTS_PATH := "res://app/front/room/room_defaults.gd"
const CLIENT_ROOM_RUNTIME_PATH := "res://network/runtime/room_client/client_room_runtime.gd"
const LOBBY_USE_CASE_PATH := "res://app/front/lobby/lobby_use_case.gd"
const LOBBY_DIRECTORY_USE_CASE_PATH := "res://app/front/lobby/lobby_directory_use_case.gd"
const FRONT_SETTINGS_STATE_PATH := "res://app/front/profile/front_settings_state.gd"
const ROOM_SERVICE_CONTRACT_DOC_PATH := "res://docs/platform_room/room_service_runtime_contract.md"


func test_room_default_port_contract() -> void:
	var env_text := _read_text(ROOM_SERVICE_ENV_EXAMPLE_PATH)
	assert_false(env_text.is_empty(), "file should be readable: %s" % ROOM_SERVICE_ENV_EXAMPLE_PATH)
	if env_text.is_empty():
		return
	var default_port := _parse_env_int(env_text, "ROOM_DEFAULT_PORT")
	var service_port := _parse_env_int(env_text, "ROOM_SERVICE_PORT")
	assert_true(default_port > 0, "ROOM_DEFAULT_PORT should be defined and > 0")
	assert_true(service_port > 0, "ROOM_SERVICE_PORT should be defined and > 0")
	assert_eq(default_port, service_port, "ROOM_DEFAULT_PORT should match ROOM_SERVICE_PORT")

	_assert_contains(ROOM_SERVICE_CONTRACT_DOC_PATH, "Default listen port: `%d`" % default_port)
	_assert_contains(ROOM_DEFAULTS_PATH, "const DEFAULT_PORT := %d" % default_port)
	_assert_contains(CLIENT_ROOM_RUNTIME_PATH, "RoomDefaultsScript.DEFAULT_PORT")
	_assert_contains(LOBBY_USE_CASE_PATH, "RoomDefaultsScript.DEFAULT_PORT")
	_assert_contains(LOBBY_DIRECTORY_USE_CASE_PATH, "RoomDefaultsScript.DEFAULT_PORT")
	_assert_contains(FRONT_SETTINGS_STATE_PATH, "RoomDefaultsScript.DEFAULT_PORT")


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


func _parse_env_int(env_text: String, key: String) -> int:
	var prefix := "%s=" % key
	for line in env_text.split("\n"):
		var trimmed := line.strip_edges()
		if trimmed.is_empty() or trimmed.begins_with("#"):
			continue
		if trimmed.begins_with(prefix):
			var raw := trimmed.substr(prefix.length(), trimmed.length() - prefix.length()).strip_edges()
			return int(raw.to_int())
	return 0
