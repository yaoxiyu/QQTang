extends Node

const TestAssert = preload("res://tests/helpers/test_assert.gd")
const MatchStartCoordinatorScript = preload("res://network/session/match_start_coordinator.gd")
const RuntimeMessageRouterScript = preload("res://network/session/runtime/runtime_message_router.gd")
const AuthorityRuntimeScript = preload("res://network/session/runtime/authority_runtime.gd")
const ClientRuntimeScript = preload("res://network/session/runtime/client_runtime.gd")
const BattleStartConfigScript = preload("res://gameplay/battle/config/battle_start_config.gd")
const TransportMessageTypesScript = preload("res://network/transport/transport_message_types.gd")
const MapCatalogScript = preload("res://content/maps/catalog/map_catalog.gd")
const ModeCatalogScript = preload("res://content/modes/catalog/mode_catalog.gd")
const RuleSetCatalogScript = preload("res://content/rulesets/catalog/rule_set_catalog.gd")
const CharacterCatalogScript = preload("res://content/characters/catalog/character_catalog.gd")


func _ready() -> void:
	var ok := true
	ok = _test_join_accepted_starts_client_runtime() and ok
	ok = _test_invalid_config_is_rejected_before_client_runtime_starts() and ok
	if ok:
		print("host_client_bootstrap_test: PASS")


func _test_join_accepted_starts_client_runtime() -> bool:
	var coordinator := MatchStartCoordinatorScript.new()
	var router := RuntimeMessageRouterScript.new()
	var authority := AuthorityRuntimeScript.new()
	var client := ClientRuntimeScript.new()
	add_child(coordinator)
	add_child(router)
	add_child(authority)
	add_child(client)

	var accepted_state := {"value": false}
	client.config_accepted.connect(func(_config) -> void:
		accepted_state["value"] = true
	)
	router.register_handler(TransportMessageTypesScript.JOIN_BATTLE_ACCEPTED, func(message: Dictionary) -> void:
		var config := BattleStartConfigScript.from_dict(message.get("start_config", {}))
		var validation := coordinator.validate_start_config(config)
		if bool(validation.get("ok", false)):
			client.configure(2)
			client.start_match(config)
	)

	var config := coordinator.build_start_config(_make_room_snapshot())
	authority.configure(1)
	var prefix := "host_client_bootstrap_test"
	var ok := true
	ok = TestAssert.is_true(authority.start_match(config), "authority runtime should start with a valid start config", prefix) and ok
	router.route_messages([{
		"message_type": TransportMessageTypesScript.JOIN_BATTLE_ACCEPTED,
		"msg_type": TransportMessageTypesScript.JOIN_BATTLE_ACCEPTED,
		"start_config": config.to_dict(),
	}])
	ok = TestAssert.is_true(bool(accepted_state.get("value", false)), "client should accept JOIN_BATTLE_ACCEPTED config", prefix) and ok
	ok = TestAssert.is_true(client.is_active(), "client runtime should become active after accepted config", prefix) and ok
	ok = TestAssert.is_true(client.start_config != null and client.start_config.match_id == config.match_id, "client runtime should keep the accepted match_id", prefix) and ok
	_cleanup_nodes([authority, client, router, coordinator])
	return ok


func _test_invalid_config_is_rejected_before_client_runtime_starts() -> bool:
	var coordinator := MatchStartCoordinatorScript.new()
	var router := RuntimeMessageRouterScript.new()
	var client := ClientRuntimeScript.new()
	add_child(coordinator)
	add_child(router)
	add_child(client)

	var rejected_errors: Array[String] = []
	router.register_handler(TransportMessageTypesScript.JOIN_BATTLE_ACCEPTED, func(message: Dictionary) -> void:
		var config := BattleStartConfigScript.from_dict(message.get("start_config", {}))
		var validation := coordinator.validate_start_config(config)
		if not bool(validation.get("ok", false)):
			rejected_errors.assign(validation.get("errors", []))
			return
		client.configure(2)
		client.start_match(config)
	)

	var invalid_config := coordinator.build_start_config(_make_room_snapshot())
	invalid_config.map_content_hash = "tampered_hash"
	router.route_messages([{
		"message_type": TransportMessageTypesScript.JOIN_BATTLE_ACCEPTED,
		"msg_type": TransportMessageTypesScript.JOIN_BATTLE_ACCEPTED,
		"start_config": invalid_config.to_dict(),
	}])
	var prefix := "host_client_bootstrap_test"
	var ok := true
	ok = TestAssert.is_true(not client.is_active(), "client runtime should stay inactive when config validation fails", prefix) and ok
	ok = TestAssert.is_true(rejected_errors.size() > 0, "invalid config should produce visible validation errors", prefix) and ok
	_cleanup_nodes([client, router, coordinator])
	return ok




func _make_room_snapshot() -> RoomSnapshot:
	var snapshot := RoomSnapshot.new()
	snapshot.room_id = "bootstrap_test_room"
	snapshot.owner_peer_id = 1
	snapshot.selected_map_id = MapCatalogScript.get_default_map_id()
	snapshot.rule_set_id = RuleSetCatalogScript.get_default_rule_id()
	snapshot.mode_id = ModeCatalogScript.get_default_mode_id()
	snapshot.all_ready = true
	snapshot.max_players = 2

	var character_id := CharacterCatalogScript.get_default_character_id()
	var host := RoomMemberState.new()
	host.peer_id = 1
	host.player_name = "Host"
	host.ready = true
	host.slot_index = 0
	host.character_id = character_id
	snapshot.members.append(host)

	var client := RoomMemberState.new()
	client.peer_id = 2
	client.player_name = "Client"
	client.ready = true
	client.slot_index = 1
	client.character_id = character_id
	snapshot.members.append(client)
	return snapshot


func _cleanup_nodes(nodes: Array) -> void:
	for node in nodes:
		if node == null:
			continue
		if node.has_method("shutdown_runtime"):
			node.shutdown_runtime()
		if is_instance_valid(node):
			node.queue_free()
