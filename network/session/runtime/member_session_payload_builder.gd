class_name MemberSessionPayloadBuilder
extends RefCounted

const TransportMessageTypesScript = preload("res://network/transport/transport_message_types.gd")


func build(room_state: RoomServerState, binding: RoomMemberBindingState, reconnect_token: String) -> Dictionary:
	if room_state == null or binding == null:
		return {}
	var token := reconnect_token.strip_edges()
	if token.is_empty():
		return {}
	return {
		"message_type": TransportMessageTypesScript.ROOM_MEMBER_SESSION,
		"room_id": room_state.room_id,
		"room_kind": room_state.room_kind,
		"room_display_name": room_state.room_display_name,
		"member_id": binding.member_id,
		"reconnect_token": token,
	}
