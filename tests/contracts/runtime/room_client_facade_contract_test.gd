extends "res://tests/gut/base/qqt_contract_test.gd"

const ROOM_USE_CASE_PATH := "res://app/front/room/room_use_case.gd"
const ROOM_GATEWAY_PATH := "res://network/runtime/room_client/room_client_gateway.gd"
const CLIENT_ROOM_RUNTIME_PATH := "res://network/runtime/room_client/client_room_runtime.gd"
const ROOM_WS_CLIENT_CS_PATH := "res://network/client_net/room/RoomWsClient.cs"


func test_front_use_case_does_not_depend_on_protobuf_bytes() -> void:
	_assert_not_contains(ROOM_USE_CASE_PATH, "PackedByteArray")
	_assert_not_contains(ROOM_USE_CASE_PATH, "protobuf")
	_assert_not_contains(ROOM_USE_CASE_PATH, "Proto")


func test_room_runtime_bridges_ws_client_events() -> void:
	_assert_contains(CLIENT_ROOM_RUNTIME_PATH, "RoomWsClientScript")
	_assert_contains(CLIENT_ROOM_RUNTIME_PATH, "_on_ws_client_message_received")
	_assert_contains(CLIENT_ROOM_RUNTIME_PATH, "_on_transport_connected")
	_assert_contains(ROOM_WS_CLIENT_CS_PATH, "MessageReceivedEventHandler")
	_assert_contains(ROOM_GATEWAY_PATH, "transport_connected")
	_assert_contains(ROOM_GATEWAY_PATH, "room_snapshot_received")
	_assert_contains(ROOM_GATEWAY_PATH, "room_error")


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
