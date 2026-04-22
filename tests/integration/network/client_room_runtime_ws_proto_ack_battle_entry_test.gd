extends "res://tests/gut/base/qqt_integration_test.gd"

const ClientRoomRuntimeScript = preload("res://network/runtime/room_client/client_room_runtime.gd")


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

	runtime.request_ack_battle_entry("assign_test", "battle_test")

	var prefix := "client_room_runtime_ws_proto_ack_battle_entry_test"
	var ok := true
	ok = qqt_check(ws.sent_messages.size() == 1, "ack battle entry should be forwarded to ws client", prefix) and ok
	if ws.sent_messages.size() > 0:
		var message := ws.sent_messages[0]
		ok = qqt_check(String(message.get("message_type", "")) == "ROOM_ACK_BATTLE_ENTRY", "ack battle entry should keep ROOM_ACK_BATTLE_ENTRY semantics", prefix) and ok
		ok = qqt_check(String(message.get("assignment_id", "")) == "assign_test", "ack battle entry should preserve assignment_id", prefix) and ok
		ok = qqt_check(String(message.get("battle_id", "")) == "battle_test", "ack battle entry should preserve battle_id", prefix) and ok

	runtime.queue_free()

