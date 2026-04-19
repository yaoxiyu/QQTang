extends "res://tests/gut/base/qqt_contract_test.gd"

const ROOM_WS_CLIENT_CS_PATH := "res://network/client_net/room/RoomWsClient.cs"
const ROOM_PROTO_CODEC_CS_PATH := "res://network/client_net/room/RoomProtoCodec.cs"
const CLIENT_ROOM_RUNTIME_GD_PATH := "res://network/runtime/room_client/client_room_runtime.gd"


func test_room_ws_client_no_json_fallback_in_formal_path() -> void:
	_assert_not_contains(ROOM_WS_CLIENT_CS_PATH, "JsonSerializer.Serialize")
	_assert_not_contains(ROOM_WS_CLIENT_CS_PATH, "Encoding.UTF8.GetBytes")
	_assert_not_contains(ROOM_WS_CLIENT_CS_PATH, "TryParseJsonDictionary")


func test_room_proto_codec_requires_typed_envelope() -> void:
	_assert_contains(ROOM_PROTO_CODEC_CS_PATH, "Typed protobuf ClientEnvelope is required")
	_assert_not_contains(ROOM_PROTO_CODEC_CS_PATH, "JsonSerializer.Serialize")


func test_runtime_formal_receive_path_uses_message_mapper_output() -> void:
	_assert_contains(CLIENT_ROOM_RUNTIME_GD_PATH, "_on_ws_client_message_received")
	_assert_not_contains(CLIENT_ROOM_RUNTIME_GD_PATH, "JSON.parse")


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
