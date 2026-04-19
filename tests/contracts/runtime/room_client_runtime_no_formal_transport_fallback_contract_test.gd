extends "res://tests/gut/base/qqt_contract_test.gd"

const CLIENT_ROOM_RUNTIME_GD_PATH := "res://network/runtime/room_client/client_room_runtime.gd"


func test_transport_adapter_is_explicitly_test_only() -> void:
	_assert_contains(CLIENT_ROOM_RUNTIME_GD_PATH, "var _transport = null # compat/test-only transport adapter")
	_assert_contains(CLIENT_ROOM_RUNTIME_GD_PATH, "func inject_test_room_transport(adapter: Node) -> void")


func test_formal_send_path_prefers_ws_client() -> void:
	_assert_contains(CLIENT_ROOM_RUNTIME_GD_PATH, "if _ws_client != null and _ws_client.has_method(\"SendMessage\") and _connected:")
	_assert_contains(CLIENT_ROOM_RUNTIME_GD_PATH, "if _allow_test_transport_fallback and _transport != null")


func _assert_contains(path: String, pattern: String) -> void:
	var text := _read_text(path)
	assert_false(text.is_empty(), "file should be readable: %s" % path)
	if text.is_empty():
		return
	assert_true(text.find(pattern) >= 0, "expected pattern missing in %s: %s" % [path, pattern])


func _read_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	return file.get_as_text()
