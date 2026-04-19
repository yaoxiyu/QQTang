extends "res://tests/gut/base/qqt_integration_test.gd"

const ClientRoomRuntimeScript = preload("res://network/runtime/room_client/client_room_runtime.gd")
const TransportMessageTypesScript = preload("res://network/transport/transport_message_types.gd")


class FakeWsClient extends Node:
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

	runtime.request_resume_room(
		"ROOM_3",
		"member_1",
		"reconnect_1",
		"match_1",
		"ticket_resume"
	)

	var ok := true
	var prefix := "client_room_runtime_ws_proto_resume_room_test"
	ok = qqt_check(ws.sent_messages.size() == 1, "resume_room should be forwarded to ws client", prefix) and ok
	if ws.sent_messages.size() > 0:
		var sent := ws.sent_messages[0]
		ok = qqt_check(
			String(sent.get("message_type", "")) == TransportMessageTypesScript.ROOM_RESUME_REQUEST,
			"resume_room should keep ROOM_RESUME_REQUEST semantics",
			prefix
		) and ok
		ok = qqt_check(String(sent.get("member_id", "")) == "member_1", "resume member_id should be preserved", prefix) and ok
	runtime.queue_free()
