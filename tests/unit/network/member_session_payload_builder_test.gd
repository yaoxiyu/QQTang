extends "res://tests/gut/base/qqt_unit_test.gd"

const RoomServerStateScript = preload("res://network/session/runtime/room_server_state.gd")
const MemberSessionPayloadBuilderScript = preload("res://network/session/runtime/member_session_payload_builder.gd")
const TransportMessageTypesScript = preload("res://network/transport/transport_message_types.gd")


func test_main() -> void:
	var ok := true
	ok = _test_build_member_session_payload() and ok


func _test_build_member_session_payload() -> bool:
	var state := RoomServerStateScript.new()
	state.ensure_room("room_payload", 2, "private_room", "Payload Room")
	var binding := state.create_member_binding(2, "Player2", "hero_default")
	var token := String(binding.reconnect_token)
	var builder := MemberSessionPayloadBuilderScript.new()
	var payload := builder.build(state, binding, token)
	var prefix := "member_session_payload_builder_test"
	var ok := true
	ok = qqt_check(String(payload.get("message_type", "")) == TransportMessageTypesScript.ROOM_MEMBER_SESSION, "payload should be ROOM_MEMBER_SESSION", prefix) and ok
	ok = qqt_check(String(payload.get("room_id", "")) == "room_payload", "payload should include room id", prefix) and ok
	ok = qqt_check(String(payload.get("member_id", "")) == binding.member_id, "payload should include member id", prefix) and ok
	ok = qqt_check(String(payload.get("reconnect_token", "")) == token, "payload should include plaintext token for client delivery", prefix) and ok
	return ok

