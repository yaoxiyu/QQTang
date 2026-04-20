extends "res://tests/gut/base/qqt_integration_test.gd"

const ClientRoomRuntimeScript = preload("res://network/runtime/room_client/client_room_runtime.gd")
const TransportMessageTypesScript = preload("res://network/transport/transport_message_types.gd")


class FakeWsClient extends RefCounted:
	var sent_messages: Array[Dictionary] = []

	func SendMessage(message: Dictionary) -> int:
		sent_messages.append(message.duplicate(true))
		return 0


func test_main() -> void:
	call_deferred("_main_body")


func _main_body() -> void:
	var runtime := ClientRoomRuntimeScript.new()
	add_child(runtime)
	runtime.set_process(false)
	var ws := FakeWsClient.new()
	runtime._ws_client = ws
	runtime._connected = true

	runtime.request_create_room(
		"ROOM_1",
		"owner",
		"char_default",
		"",
		"bubble_default",
		"",
		"map_arcade",
		"ruleset_classic",
		"mode_classic",
		"private_room",
		"Room Alpha",
		"ticket_create"
	)

	var ok := true
	var prefix := "client_room_runtime_ws_proto_create_room_test"
	ok = qqt_check(ws.sent_messages.size() == 1, "create_room should be forwarded to ws client", prefix) and ok
	if ws.sent_messages.size() > 0:
		ok = qqt_check(
			String(ws.sent_messages[0].get("message_type", "")) == TransportMessageTypesScript.ROOM_CREATE_REQUEST,
			"create_room should keep ROOM_CREATE_REQUEST semantics",
			prefix
		) and ok
	runtime.queue_free()

