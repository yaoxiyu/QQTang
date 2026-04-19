extends "res://tests/gut/base/qqt_unit_test.gd"

const CharacterCatalogScript = preload("res://content/characters/catalog/character_catalog.gd")
const RoomViewModelBuilderScript = preload("res://app/front/room/room_view_model_builder.gd")
const TransportMessageTypesScript = preload("res://network/transport/transport_message_types.gd")
const RoomSessionControllerScript = preload("res://network/session/room_session_controller.gd")
const ServerRoomServiceScript = preload("res://network/session/legacy/server_room_service.gd")
const BattleStartConfigScript = preload("res://gameplay/battle/config/battle_start_config.gd")
const RoomMemberStateScript = preload("res://gameplay/battle/config/room_member_state.gd")


func test_main() -> void:
	var ok := true
	ok = _test_local_ready_member_cannot_change_team() and ok
	ok = _test_local_single_team_start_is_blocked() and ok
	ok = _test_start_config_rejects_single_team() and ok
	ok = _test_server_ready_member_cannot_change_team() and ok
	ok = _test_server_single_team_start_is_blocked() and ok


func _test_local_ready_member_cannot_change_team() -> bool:
	var controller = RoomSessionControllerScript.new()
	add_child(controller)
	controller.create_room(1)
	controller.set_local_player_id(1)
	var host_profile_result: Dictionary = controller.request_update_member_profile(1, "P1", _character_id(), "", "", "", 1)
	var peer: RoomMemberState = _member(2, "P2", 1)
	controller.join_room(peer)
	controller.set_member_ready(1, true)

	var result: Dictionary = controller.request_update_member_profile(1, "P1", _character_id(), "", "", "", 2)
	var snapshot: RoomSnapshot = controller.build_room_snapshot()
	var host: RoomMemberState = _find_member(snapshot, 1)
	var view_model: Dictionary = RoomViewModelBuilderScript.new().build_view_model(snapshot, controller.room_runtime_context, null, null)
	var prefix := "room_team_start_guard_test.local_ready_team"
	var ok := true
	ok = qqt_check(bool(host_profile_result.get("ok", false)), "host profile setup should pass", prefix) and ok
	ok = qqt_check(not bool(result.get("ok", true)), "ready local member team change should be rejected", prefix) and ok
	ok = qqt_check(host != null and host.team_id == 1, "ready local member team should remain unchanged", prefix) and ok
	ok = qqt_check(not bool(view_model.get("can_edit_team", true)), "ready local member team selector should be disabled by view model", prefix) and ok
	controller.queue_free()
	return ok


func _test_local_single_team_start_is_blocked() -> bool:
	var controller = RoomSessionControllerScript.new()
	add_child(controller)
	controller.create_room(1)
	controller.request_update_member_profile(1, "P1", _character_id(), "", "", "", 1)
	controller.join_room(_member(2, "P2", 1))
	controller.set_member_ready(1, true)
	controller.set_member_ready(2, true)

	var blocker: Dictionary = controller.get_start_match_blocker(1)
	var prefix := "room_team_start_guard_test.local_single_team_start"
	var ok := true
	ok = qqt_check(not controller.can_start_match(), "local same-team room should not be startable", prefix) and ok
	ok = qqt_check(String(blocker.get("error_code", "")) == "ROOM_TEAM_INVALID", "local same-team blocker should report team invalid", prefix) and ok
	controller.queue_free()
	return ok


func _test_start_config_rejects_single_team() -> bool:
	var config: BattleStartConfig = BattleStartConfigScript.new()
	config.room_id = "team_guard_room"
	config.match_id = "team_guard_match"
	config.map_id = "map"
	config.mode_id = "mode"
	config.rule_set_id = "rule"
	config.map_content_hash = "hash"
	config.local_peer_id = 1
	config.controlled_peer_id = 1
	config.owner_peer_id = 1
	config.player_slots = [
		{"peer_id": 1, "slot_index": 0, "team_id": 1},
		{"peer_id": 2, "slot_index": 1, "team_id": 1},
	]
	config.players = config.player_slots.duplicate(true)
	config.spawn_assignments = [
		{"peer_id": 1, "slot_index": 0},
		{"peer_id": 2, "slot_index": 1},
	]
	var validation := config.validate()
	var prefix := "room_team_start_guard_test.config_single_team"
	return qqt_check(
		not bool(validation.get("ok", true)) and _errors_contain(validation, "at least two team_id"),
		"BattleStartConfig should reject single-team player slots",
		prefix
	)


func _test_server_ready_member_cannot_change_team() -> bool:
	var service = ServerRoomServiceScript.new()
	add_child(service)
	var directed: Array[Dictionary] = []
	service.send_to_peer.connect(func(peer_id: int, message: Dictionary) -> void:
		directed.append({"peer_id": peer_id, "message": message.duplicate(true)})
	)
	service.room_state.ensure_room("server_room", 1, "private_room", "")
	service.room_state.upsert_member(1, "P1", _character_id(), "", "", "", 1)
	service.room_state.upsert_member(2, "P2", _character_id(), "", "", "", 2)
	service.room_state.set_ready(1, true)

	service.handle_message({
		"message_type": TransportMessageTypesScript.ROOM_UPDATE_PROFILE,
		"sender_peer_id": 1,
		"player_name": "P1",
		"character_id": _character_id(),
		"team_id": 2,
	})

	var reject := _find_latest_message(directed, 1, TransportMessageTypesScript.JOIN_BATTLE_REJECTED)
	var profile: Dictionary = service.room_state.members.get(1, {})
	var prefix := "room_team_start_guard_test.server_ready_team"
	var ok := true
	ok = qqt_check(String(reject.get("error", "")) == "ROOM_MEMBER_PROFILE_FORBIDDEN", "server should reject ready member team change", prefix) and ok
	ok = qqt_check(int(profile.get("team_id", 0)) == 1, "server team should remain unchanged", prefix) and ok
	service.queue_free()
	return ok


func _test_server_single_team_start_is_blocked() -> bool:
	var service = ServerRoomServiceScript.new()
	add_child(service)
	var directed: Array[Dictionary] = []
	service.send_to_peer.connect(func(peer_id: int, message: Dictionary) -> void:
		directed.append({"peer_id": peer_id, "message": message.duplicate(true)})
	)
	service.room_state.ensure_room("server_room", 1, "private_room", "")
	service.room_state.upsert_member(1, "P1", _character_id(), "", "", "", 1)
	service.room_state.upsert_member(2, "P2", _character_id(), "", "", "", 1)
	service.room_state.set_ready(1, true)
	service.room_state.set_ready(2, true)

	service.handle_message({
		"message_type": TransportMessageTypesScript.ROOM_START_REQUEST,
		"sender_peer_id": 1,
	})

	var reject := _find_latest_message(directed, 1, TransportMessageTypesScript.JOIN_BATTLE_REJECTED)
	var prefix := "room_team_start_guard_test.server_single_team_start"
	var ok := true
	ok = qqt_check(not service.room_state.can_start(), "server same-team room should not be startable", prefix) and ok
	ok = qqt_check(String(reject.get("error", "")) == "ROOM_TEAM_INVALID", "server same-team start should be rejected", prefix) and ok
	service.queue_free()
	return ok


func _member(peer_id: int, player_name: String, team_id: int) -> RoomMemberState:
	var member: RoomMemberState = RoomMemberStateScript.new()
	member.peer_id = peer_id
	member.player_name = player_name
	member.character_id = _character_id()
	member.team_id = team_id
	return member


func _find_member(snapshot: RoomSnapshot, peer_id: int) -> RoomMemberState:
	for member in snapshot.members:
		if member != null and member.peer_id == peer_id:
			return member
	return null


func _find_latest_message(messages: Array[Dictionary], peer_id: int, message_type: String) -> Dictionary:
	for index in range(messages.size() - 1, -1, -1):
		var entry: Dictionary = messages[index]
		if int(entry.get("peer_id", 0)) != peer_id:
			continue
		var message: Dictionary = entry.get("message", {})
		if String(message.get("message_type", "")) == message_type:
			return message
	return {}


func _errors_contain(validation: Dictionary, needle: String) -> bool:
	for error in validation.get("errors", []):
		if String(error).contains(needle):
			return true
	return false


func _character_id() -> String:
	return CharacterCatalogScript.get_default_character_id()

