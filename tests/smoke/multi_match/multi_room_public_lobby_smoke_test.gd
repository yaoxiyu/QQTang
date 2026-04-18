extends "res://tests/gut/base/qqt_smoke_test.gd"

const AppRuntimeRootScript = preload("res://app/flow/app_runtime_root.gd")
const BubbleCatalogScript = preload("res://content/bubbles/catalog/bubble_catalog.gd")
const CharacterCatalogScript = preload("res://content/characters/catalog/character_catalog.gd")
const FrontFlowControllerScript = preload("res://app/flow/front_flow_controller.gd")
const MapCatalogScript = preload("res://content/maps/catalog/map_catalog.gd")
const ModeCatalogScript = preload("res://content/modes/catalog/mode_catalog.gd")
const RoomMemberStateScript = preload("res://gameplay/battle/config/room_member_state.gd")
const RoomSnapshotScript = preload("res://gameplay/battle/config/room_snapshot.gd")
const RuleSetCatalogScript = preload("res://content/rulesets/catalog/rule_set_catalog.gd")
const ServerRoomRegistryScript = preload("res://network/session/runtime/server_room_registry.gd")
const TransportMessageTypesScript = preload("res://network/transport/transport_message_types.gd")
const ROOM_TICKET_SECRET := "dev_room_ticket_secret"

class FakeRoomTicketGateway:
	extends RefCounted

	func configure_base_url(_base_url: String) -> void:
		pass

	func issue_room_ticket(_access_token: String, _request):
		var result = preload("res://app/front/auth/room_ticket_result.gd").new()
		result.ok = true
		result.ticket = "ticket_smoke"
		result.ticket_id = "ticket_id_smoke"
		result.account_id = "account_smoke"
		result.profile_id = "profile_smoke"
		result.device_session_id = "device_session_smoke"
		return result


func test_public_lobby_multi_room_smoke() -> void:
	var registry := qqt_add_child(ServerRoomRegistryScript.new())
	var runtime: Node = AppRuntimeRootScript.ensure_in_tree(get_tree())
	await qqt_wait_frames(2)
	runtime.auth_session_state.access_token = "access_smoke"
	runtime.room_ticket_gateway = FakeRoomTicketGateway.new()
	runtime.lobby_use_case.configure(
		runtime,
		runtime.auth_session_state,
		runtime.player_profile_state,
		runtime.front_settings_state,
		runtime.practice_room_factory,
		runtime.auth_session_repository,
		runtime.logout_use_case,
		runtime.profile_gateway,
		runtime.room_ticket_gateway
	)
	runtime.front_flow.enter_lobby()

	var mode_id := ModeCatalogScript.get_default_mode_id()
	var mode_metadata := ModeCatalogScript.get_mode_metadata(mode_id)
	var rule_id := String(mode_metadata.get("rule_set_id", RuleSetCatalogScript.get_default_rule_id()))
	var map_id := String(mode_metadata.get("default_map_id", MapCatalogScript.get_default_map_id()))

	registry.route_message(_create_room_message(1, "public_room", "Smoke Public", map_id, rule_id, mode_id))
	registry.route_message(_join_room_message(2, String(registry.peer_room_bindings.get(1, ""))))
	registry.route_message(_create_room_message(3, "private_room", "", map_id, rule_id, mode_id))
	registry.route_message(_join_room_message(4, String(registry.peer_room_bindings.get(3, ""))))
	await qqt_wait_frames(1)

	var directory_snapshot = registry.build_directory_snapshot()
	var public_entry = directory_snapshot.entries[0] if not directory_snapshot.entries.is_empty() else null
	var public_room_id := String(registry.peer_room_bindings.get(1, ""))
	assert_true(not public_room_id.is_empty(), "public room binding should exist")
	assert_not_null(public_entry, "public room directory entry should exist")

	var room_result: Dictionary = runtime.room_use_case.enter_room(
		runtime.lobby_use_case.join_public_room("127.0.0.1", 9000, public_room_id).get("entry_context", null)
	)
	runtime.room_use_case.call("_on_gateway_room_snapshot_received", _make_public_room_snapshot(map_id, rule_id, mode_id))
	var start_config = runtime.match_start_coordinator.build_server_canonical_config(
		_make_public_room_snapshot(map_id, rule_id, mode_id),
		"127.0.0.1",
		9000,
		1
	)
	runtime.room_use_case.call("_on_gateway_canonical_start_config_received", start_config)
	runtime.front_flow.on_loading_completed()

	assert_eq(directory_snapshot.entries.size(), 1, "smoke directory should only list public room")
	assert_true(public_entry != null and String(public_entry.room_display_name) == "Smoke Public", "smoke directory should expose public room display name")
	assert_true(bool(room_result.get("pending", false)), "public room lobby entry should begin in pending state")
	assert_true(runtime.front_flow.is_in_state(FrontFlowControllerScript.FlowState.BATTLE), "public room smoke flow should reach battle after room and loading")
	assert_eq(registry.room_runtimes.size(), 2, "multi-room smoke should keep both public and private runtimes alive")

	if is_instance_valid(runtime):
		qqt_detach_and_free(runtime)
	if is_instance_valid(registry):
		qqt_detach_and_free(registry)
	await qqt_wait_frames(2)


func _create_room_message(peer_id: int, room_kind: String, room_display_name: String, map_id: String, rule_id: String, mode_id: String) -> Dictionary:
	var ticket := _make_room_ticket({
		"ticket_id": "ticket_create_%d" % peer_id,
		"account_id": "account_%d" % peer_id,
		"profile_id": "profile_%d" % peer_id,
		"device_session_id": "dsess_%d" % peer_id,
		"purpose": "create",
		"room_id": "",
		"room_kind": room_kind,
		"requested_match_id": "",
		"display_name": "Player%d" % peer_id,
		"allowed_character_ids": [CharacterCatalogScript.get_default_character_id()],
		"allowed_character_skin_ids": [""],
		"allowed_bubble_style_ids": [BubbleCatalogScript.get_default_bubble_id()],
		"allowed_bubble_skin_ids": [""],
		"issued_at_unix_sec": int(Time.get_unix_time_from_system()) - 5,
		"expire_at_unix_sec": int(Time.get_unix_time_from_system()) + 60,
		"nonce": "nonce_create_%d" % peer_id,
	})
	return {
		"message_type": TransportMessageTypesScript.ROOM_CREATE_REQUEST,
		"sender_peer_id": peer_id,
		"room_id_hint": "",
		"room_kind": room_kind,
		"room_display_name": room_display_name,
		"player_name": "Player%d" % peer_id,
		"character_id": CharacterCatalogScript.get_default_character_id(),
		"map_id": map_id,
		"rule_set_id": rule_id,
		"mode_id": mode_id,
		"room_ticket": ticket.get("token", ""),
		"room_ticket_id": ticket.get("ticket_id", ""),
		"account_id": ticket.get("account_id", ""),
		"profile_id": ticket.get("profile_id", ""),
		"device_session_id": ticket.get("device_session_id", ""),
	}


func _join_room_message(peer_id: int, room_id: String) -> Dictionary:
	var ticket := _make_room_ticket({
		"ticket_id": "ticket_join_%d" % peer_id,
		"account_id": "account_%d" % peer_id,
		"profile_id": "profile_%d" % peer_id,
		"device_session_id": "dsess_%d" % peer_id,
		"purpose": "join",
		"room_id": room_id,
		"room_kind": "",
		"requested_match_id": "",
		"display_name": "Player%d" % peer_id,
		"allowed_character_ids": [CharacterCatalogScript.get_default_character_id()],
		"allowed_character_skin_ids": [""],
		"allowed_bubble_style_ids": [BubbleCatalogScript.get_default_bubble_id()],
		"allowed_bubble_skin_ids": [""],
		"issued_at_unix_sec": int(Time.get_unix_time_from_system()) - 5,
		"expire_at_unix_sec": int(Time.get_unix_time_from_system()) + 60,
		"nonce": "nonce_join_%d" % peer_id,
	})
	return {
		"message_type": TransportMessageTypesScript.ROOM_JOIN_REQUEST,
		"sender_peer_id": peer_id,
		"room_id_hint": room_id,
		"player_name": "Player%d" % peer_id,
		"character_id": CharacterCatalogScript.get_default_character_id(),
		"room_ticket": ticket.get("token", ""),
		"room_ticket_id": ticket.get("ticket_id", ""),
		"account_id": ticket.get("account_id", ""),
		"profile_id": ticket.get("profile_id", ""),
		"device_session_id": ticket.get("device_session_id", ""),
	}


func _make_room_ticket(payload: Dictionary) -> Dictionary:
	var json := JSON.stringify(payload)
	var encoded_payload := Marshalls.raw_to_base64(json.to_utf8_buffer()).replace("+", "-").replace("/", "_").trim_suffix("=")
	var crypto := Crypto.new()
	var digest := crypto.hmac_digest(HashingContext.HASH_SHA256, ROOM_TICKET_SECRET.to_utf8_buffer(), encoded_payload.to_utf8_buffer())
	var signature := Marshalls.raw_to_base64(digest).replace("+", "-").replace("/", "_").trim_suffix("=")
	var token := "%s.%s" % [encoded_payload, signature]
	var result := payload.duplicate(true)
	result["token"] = token
	return result


func _make_public_room_snapshot(map_id: String, rule_id: String, mode_id: String) -> RoomSnapshot:
	var snapshot := RoomSnapshotScript.new()
	snapshot.room_id = "ROOM-SMOKE-PUBLIC"
	snapshot.room_kind = "public_room"
	snapshot.room_display_name = "Smoke Public"
	snapshot.topology = "dedicated_server"
	snapshot.owner_peer_id = 1
	snapshot.selected_map_id = map_id
	snapshot.rule_set_id = rule_id
	snapshot.mode_id = mode_id
	snapshot.max_players = 4
	snapshot.all_ready = true
	snapshot.members = [_make_member(1, "Host", true, true), _make_member(2, "Guest", true, false)]
	return snapshot


func _make_member(peer_id: int, player_name: String, ready: bool, is_owner: bool):
	var member := RoomMemberStateScript.new()
	member.peer_id = peer_id
	member.player_name = player_name
	member.ready = ready
	member.slot_index = peer_id - 1
	member.character_id = CharacterCatalogScript.get_default_character_id()
	member.is_owner = is_owner
	member.is_local_player = peer_id == 1
	member.connection_state = "connected"
	return member

