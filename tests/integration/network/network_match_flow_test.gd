extends Node

const TestAssert = preload("res://tests/helpers/test_assert.gd")
const FrontRoomKindScript = preload("res://app/front/navigation/front_room_kind.gd")
const FrontTopologyScript = preload("res://app/front/navigation/front_topology.gd")
const MatchStartCoordinatorScript = preload("res://network/session/match_start_coordinator.gd")
const AuthorityRuntimeScript = preload("res://network/session/runtime/authority_runtime.gd")
const ClientRuntimeScript = preload("res://network/session/runtime/client_runtime.gd")
const MapCatalogScript = preload("res://content/maps/catalog/map_catalog.gd")
const ModeCatalogScript = preload("res://content/modes/catalog/mode_catalog.gd")
const RuleSetCatalogScript = preload("res://content/rulesets/catalog/rule_set_catalog.gd")
const TransportMessageTypesScript = preload("res://network/transport/transport_message_types.gd")

var _host_result: BattleResult = null
var _client_result: BattleResult = null


func _ready() -> void:
	var ok := _test_authority_client_match_flow_reaches_consistent_end()
	if ok:
		print("network_match_flow_test: PASS")


func _test_authority_client_match_flow_reaches_consistent_end() -> bool:
	var coordinator := MatchStartCoordinatorScript.new()
	var authority := AuthorityRuntimeScript.new()
	var client := ClientRuntimeScript.new()
	add_child(coordinator)
	add_child(authority)
	add_child(client)

	_host_result = null
	_client_result = null
	authority.battle_finished.connect(func(result: BattleResult) -> void:
		_host_result = result.duplicate_deep()
	)
	client.battle_finished.connect(func(result: BattleResult) -> void:
		_client_result = result.duplicate_deep()
	)

	var config := coordinator.build_start_config(_make_room_snapshot())
	config.match_duration_ticks = 5
	config.sort_players()
	authority.configure(1)
	client.configure(2)

	var prefix := "network_match_flow_test"
	var ok := true
	ok = TestAssert.is_true(bool(coordinator.validate_start_config(config).get("ok", false)), "start config should validate before network flow test begins", prefix) and ok
	ok = TestAssert.is_true(authority.start_match(config), "authority runtime should start", prefix) and ok
	ok = TestAssert.is_true(client.start_match(config), "client runtime should start", prefix) and ok

	var checkpoint_seen := false
	var summary_seen := false
	for tick_index in range(8):
		var local_input := {
			"move_x": 1 if tick_index < 2 else 0,
			"move_y": 0,
			"action_place": false,
		}
		var input_message := client.build_local_input_message(local_input)
		ok = TestAssert.is_true(not input_message.is_empty(), "client should emit an input frame while match is active", prefix) and ok
		authority.ingest_network_message(input_message)
		var outgoing := authority.advance_authoritative_tick({})
		for message in outgoing:
			var message_type := String(message.get("message_type", message.get("msg_type", "")))
			if message_type == TransportMessageTypesScript.STATE_SUMMARY:
				summary_seen = true
			if message_type == TransportMessageTypesScript.CHECKPOINT:
				checkpoint_seen = true
			client.ingest_network_message(message)
		if _host_result != null and _client_result != null:
			break

	var metrics := client.build_metrics()
	ok = TestAssert.is_true(summary_seen, "authority should emit state summaries during match flow", prefix) and ok
	ok = TestAssert.is_true(checkpoint_seen, "authority should emit at least one checkpoint during match flow", prefix) and ok
	ok = TestAssert.is_true(int(metrics.get("ack_tick", 0)) >= 5, "client should receive input acknowledgements through match end", prefix) and ok
	ok = TestAssert.is_true(int(metrics.get("snapshot_tick", 0)) >= 5, "client should receive authoritative snapshots through match end", prefix) and ok
	ok = TestAssert.is_true(_host_result != null, "host should produce a battle result", prefix) and ok
	ok = TestAssert.is_true(_client_result != null, "client should receive the battle result", prefix) and ok
	if _host_result != null and _client_result != null:
		ok = TestAssert.is_true(_host_result.finish_tick == _client_result.finish_tick, "host and client should agree on finish_tick", prefix) and ok
		ok = TestAssert.is_true(_host_result.finish_reason == _client_result.finish_reason, "host and client should agree on finish_reason", prefix) and ok
		ok = TestAssert.is_true(_host_result.winner_peer_ids == _client_result.winner_peer_ids, "host and client should agree on winners", prefix) and ok

	authority.shutdown_runtime()
	client.shutdown_runtime()
	if is_instance_valid(authority):
		authority.queue_free()
	if is_instance_valid(client):
		client.queue_free()
	if is_instance_valid(coordinator):
		coordinator.queue_free()
	return ok


func _make_room_snapshot() -> RoomSnapshot:
	var snapshot := RoomSnapshot.new()
	snapshot.room_id = "network_match_flow_room"
	snapshot.room_kind = FrontRoomKindScript.PRACTICE
	snapshot.topology = FrontTopologyScript.LOCAL
	snapshot.owner_peer_id = 1
	snapshot.selected_map_id = MapCatalogScript.get_default_map_id()
	snapshot.rule_set_id = RuleSetCatalogScript.get_default_rule_id()
	snapshot.mode_id = ModeCatalogScript.get_default_mode_id()
	snapshot.min_start_players = 1
	snapshot.all_ready = true
	snapshot.max_players = 2

	var host := RoomMemberState.new()
	host.peer_id = 1
	host.player_name = "Host"
	host.ready = true
	host.slot_index = 0
	host.character_id = "hero_1"
	snapshot.members.append(host)

	var client := RoomMemberState.new()
	client.peer_id = 2
	client.player_name = "Client"
	client.ready = true
	client.slot_index = 1
	client.character_id = "hero_2"
	snapshot.members.append(client)
	return snapshot
