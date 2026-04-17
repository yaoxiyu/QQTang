extends Node

const FrontSettingsStateScript = preload("res://app/front/profile/front_settings_state.gd")
const LobbyViewStateScript = preload("res://app/front/lobby/lobby_view_state.gd")


func _ready() -> void:
	var ok := true
	ok = _test_reconnect_ticket_stores_public_room_kind() and ok
	ok = _test_lobby_view_state_carries_reconnect_kind() and ok
	ok = _test_reconnect_ticket_serialization_round_trip() and ok
	if ok:
		print("lobby_reconnect_public_room_test: PASS")


func _test_reconnect_ticket_stores_public_room_kind() -> bool:
	var settings := FrontSettingsStateScript.new()
	settings.reconnect_room_id = "pub_room_001"
	settings.reconnect_room_kind = "public_room"
	settings.reconnect_room_display_name = "My Public Room"
	settings.reconnect_topology = "dedicated_server"
	settings.reconnect_host = "127.0.0.1"
	settings.reconnect_port = 9000

	var dict := settings.to_dict()
	if dict["reconnect_room_kind"] != "public_room":
		print("FAIL: to_dict reconnect_room_kind mismatch")
		return false
	if dict["reconnect_room_display_name"] != "My Public Room":
		print("FAIL: to_dict reconnect_room_display_name mismatch")
		return false
	if dict["reconnect_topology"] != "dedicated_server":
		print("FAIL: to_dict reconnect_topology mismatch")
		return false

	var restored := FrontSettingsStateScript.from_dict(dict)
	if restored.reconnect_room_kind != "public_room":
		print("FAIL: from_dict reconnect_room_kind mismatch")
		return false
	if restored.reconnect_room_display_name != "My Public Room":
		print("FAIL: from_dict reconnect_room_display_name mismatch")
		return false
	return true


func _test_lobby_view_state_carries_reconnect_kind() -> bool:
	var view_state := LobbyViewStateScript.new()
	view_state.reconnect_room_id = "room_001"
	view_state.reconnect_room_kind = "public_room"
	view_state.reconnect_room_display_name = "Test Public Room"

	var dict := view_state.to_dict()
	if dict["reconnect_room_kind"] != "public_room":
		print("FAIL: lobby view_state to_dict reconnect_room_kind mismatch")
		return false
	if dict["reconnect_room_display_name"] != "Test Public Room":
		print("FAIL: lobby view_state to_dict reconnect_room_display_name mismatch")
		return false
	return true


func _test_reconnect_ticket_serialization_round_trip() -> bool:
	var settings := FrontSettingsStateScript.new()
	settings.reconnect_room_id = "room_123"
	settings.reconnect_room_kind = "private_room"
	settings.reconnect_room_display_name = "My Private Room"
	settings.reconnect_topology = "dedicated_server"
	settings.reconnect_match_id = "match_abc"
	settings.reconnect_host = "10.0.0.1"
	settings.reconnect_port = 8000
	settings.reconnect_token = "should_not_persist"

	var serialized := settings.to_dict()
	if serialized.has("reconnect_token"):
		print("FAIL: reconnect_token must not be serialized")
		return false
	var restored := FrontSettingsStateScript.from_dict(serialized)
	if restored.reconnect_room_id != settings.reconnect_room_id:
		print("FAIL: round_trip reconnect_room_id mismatch")
		return false
	if restored.reconnect_room_kind != settings.reconnect_room_kind:
		print("FAIL: round_trip reconnect_room_kind mismatch")
		return false
	if restored.reconnect_room_display_name != settings.reconnect_room_display_name:
		print("FAIL: round_trip reconnect_room_display_name mismatch")
		return false
	if restored.reconnect_topology != settings.reconnect_topology:
		print("FAIL: round_trip reconnect_topology mismatch")
		return false
	if restored.reconnect_match_id != settings.reconnect_match_id:
		print("FAIL: round_trip reconnect_match_id mismatch")
		return false
	if restored.reconnect_host != settings.reconnect_host:
		print("FAIL: round_trip reconnect_host mismatch")
		return false
	if restored.reconnect_port != settings.reconnect_port:
		print("FAIL: round_trip reconnect_port mismatch")
		return false
	if not restored.reconnect_token.is_empty():
		print("FAIL: reconnect_token should not be restored from serialized settings")
		return false
	return true
