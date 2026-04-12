extends Node

const RoomMemberBindingStateScript = preload("res://network/session/runtime/room_member_binding_state.gd")


func _ready() -> void:
	var ok := true
	ok = _test_round_trip_preserves_resume_fields() and ok
	if ok:
		print("room_member_binding_state_test: PASS")


func _test_round_trip_preserves_resume_fields() -> bool:
	var binding := RoomMemberBindingStateScript.new()
	binding.member_id = "member_7"
	binding.reconnect_token = "token_abc"
	binding.account_id = "account_7"
	binding.profile_id = "profile_7"
	binding.device_session_id = "dsess_7"
	binding.ticket_id = "ticket_7"
	binding.auth_claim_version = 1
	binding.display_name_source = "profile"
	binding.transport_peer_id = 42
	binding.match_peer_id = 2
	binding.player_name = "Momo"
	binding.character_id = "hero_default"
	binding.ready = true
	binding.slot_index = 1
	binding.is_owner = false
	binding.connection_state = "disconnected"
	binding.disconnect_deadline_msec = 12345
	binding.last_room_id = "room_a"
	binding.last_match_id = "match_a"

	var restored := RoomMemberBindingStateScript.from_dict(binding.to_dict())
	if restored.member_id != binding.member_id:
		print("FAIL: member_id mismatch")
		return false
	if restored.reconnect_token != binding.reconnect_token:
		print("FAIL: reconnect_token mismatch")
		return false
	if restored.account_id != binding.account_id:
		print("FAIL: account_id mismatch")
		return false
	if restored.profile_id != binding.profile_id:
		print("FAIL: profile_id mismatch")
		return false
	if restored.device_session_id != binding.device_session_id:
		print("FAIL: device_session_id mismatch")
		return false
	if restored.ticket_id != binding.ticket_id:
		print("FAIL: ticket_id mismatch")
		return false
	if restored.auth_claim_version != binding.auth_claim_version:
		print("FAIL: auth_claim_version mismatch")
		return false
	if restored.display_name_source != binding.display_name_source:
		print("FAIL: display_name_source mismatch")
		return false
	if restored.transport_peer_id != binding.transport_peer_id:
		print("FAIL: transport_peer_id mismatch")
		return false
	if restored.match_peer_id != binding.match_peer_id:
		print("FAIL: match_peer_id mismatch")
		return false
	if restored.connection_state != binding.connection_state:
		print("FAIL: connection_state mismatch")
		return false
	if restored.disconnect_deadline_msec != binding.disconnect_deadline_msec:
		print("FAIL: disconnect_deadline_msec mismatch")
		return false
	return true
