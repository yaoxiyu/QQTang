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

	runtime.request_join_room(
		"ROOM_2",
		"joiner",
		"char_default",
		"",
		"bubble_default",
		"",
		"ticket_join"
	)

	var ok := true
	var prefix := "client_room_runtime_join_room_canonical_message_test"
	ok = qqt_check(ws.sent_messages.size() == 1, "join_room should be sent through ws client", prefix) and ok
	if ws.sent_messages.size() > 0:
		ok = qqt_check(
			String(ws.sent_messages[0].get("message_type", "")) == TransportMessageTypesScript.ROOM_JOIN_REQUEST,
			"join_room message_type should keep canonical request semantics",
			prefix
		) and ok
	runtime.queue_free()

