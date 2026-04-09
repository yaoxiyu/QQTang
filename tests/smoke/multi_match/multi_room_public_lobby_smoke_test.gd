extends Node

const AppRuntimeRootScript = preload("res://app/flow/app_runtime_root.gd")
const CharacterCatalogScript = preload("res://content/characters/catalog/character_catalog.gd")
const FrontFlowControllerScript = preload("res://app/flow/front_flow_controller.gd")
const MapCatalogScript = preload("res://content/maps/catalog/map_catalog.gd")
const ModeCatalogScript = preload("res://content/modes/catalog/mode_catalog.gd")
const RoomMemberStateScript = preload("res://gameplay/battle/config/room_member_state.gd")
const RoomSnapshotScript = preload("res://gameplay/battle/config/room_snapshot.gd")
const RuleSetCatalogScript = preload("res://content/rulesets/catalog/rule_set_catalog.gd")
const ServerRoomRegistryScript = preload("res://network/session/runtime/server_room_registry.gd")
const TransportMessageTypesScript = preload("res://network/transport/transport_message_types.gd")
const TestAssert = preload("res://tests/helpers/test_assert.gd")

signal test_finished


func _ready() -> void:
	call_deferred("run_all")


func run_all() -> void:
	var ok := await _test_public_lobby_multi_room_smoke()
	if ok:
		print("multi_room_public_lobby_smoke_test: PASS")
	test_finished.emit()


func _test_public_lobby_multi_room_smoke() -> bool:
	var registry := ServerRoomRegistryScript.new()
	add_child(registry)
	var runtime: Node = AppRuntimeRootScript.ensure_in_tree(get_tree())
	await get_tree().process_frame
	await get_tree().process_frame
	runtime.front_flow.enter_lobby()

	var mode_id := ModeCatalogScript.get_default_mode_id()
	var mode_metadata := ModeCatalogScript.get_mode_metadata(mode_id)
	var rule_id := String(mode_metadata.get("rule_set_id", RuleSetCatalogScript.get_default_rule_id()))
	var map_id := String(mode_metadata.get("default_map_id", MapCatalogScript.get_default_map_id()))

	registry.route_message(_create_room_message(1, "public_room", "Smoke Public", map_id, rule_id, mode_id))
	registry.route_message(_join_room_message(2, String(registry.peer_room_bindings.get(1, ""))))
	registry.route_message(_create_room_message(3, "private_room", "", map_id, rule_id, mode_id))
	registry.route_message(_join_room_message(4, String(registry.peer_room_bindings.get(3, ""))))

	var directory_snapshot = registry.build_directory_snapshot()
	var public_entry = directory_snapshot.entries[0] if not directory_snapshot.entries.is_empty() else null

	var room_result: Dictionary = runtime.room_use_case.enter_room(
		runtime.lobby_use_case.join_public_room("127.0.0.1", 9000, String(public_entry.room_id)).get("entry_context", null)
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

	var prefix := "multi_room_public_lobby_smoke_test"
	var ok := true
	ok = TestAssert.is_true(directory_snapshot.entries.size() == 1, "smoke directory should only list public room", prefix) and ok
	ok = TestAssert.is_true(public_entry != null and String(public_entry.room_display_name) == "Smoke Public", "smoke directory should expose public room display name", prefix) and ok
	ok = TestAssert.is_true(bool(room_result.get("pending", false)), "public room lobby entry should begin in pending state", prefix) and ok
	ok = TestAssert.is_true(runtime.front_flow.is_in_state(FrontFlowControllerScript.FlowState.BATTLE), "public room smoke flow should reach battle after room and loading", prefix) and ok
	ok = TestAssert.is_true(registry.room_runtimes.size() == 2, "multi-room smoke should keep both public and private runtimes alive", prefix) and ok

	if is_instance_valid(runtime):
		runtime.queue_free()
	if is_instance_valid(registry):
		registry.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	return ok


func _create_room_message(peer_id: int, room_kind: String, room_display_name: String, map_id: String, rule_id: String, mode_id: String) -> Dictionary:
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
	}


func _join_room_message(peer_id: int, room_id: String) -> Dictionary:
	return {
		"message_type": TransportMessageTypesScript.ROOM_JOIN_REQUEST,
		"sender_peer_id": peer_id,
		"room_id_hint": room_id,
		"player_name": "Player%d" % peer_id,
		"character_id": CharacterCatalogScript.get_default_character_id(),
	}


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
