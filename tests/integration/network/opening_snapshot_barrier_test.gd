extends "res://tests/gut/base/qqt_integration_test.gd"

const FrontRoomKindScript = preload("res://app/front/navigation/front_room_kind.gd")
const FrontTopologyScript = preload("res://app/front/navigation/front_topology.gd")
const MatchStartCoordinatorScript = preload("res://network/session/match_start_coordinator.gd")
const ServerMatchServiceScript = preload("res://network/session/runtime/server_match_service.gd")
const TickRunnerScript = preload("res://gameplay/simulation/runtime/tick_runner.gd")
const TransportMessageTypesScript = preload("res://network/transport/transport_message_types.gd")
const MapCatalogScript = preload("res://content/maps/catalog/map_catalog.gd")
const ModeCatalogScript = preload("res://content/modes/catalog/mode_catalog.gd")
const RuleSetCatalogScript = preload("res://content/rulesets/catalog/rule_set_catalog.gd")


func test_opening_snapshot_barrier_blocks_ticks_until_ready_and_prevents_big_delta_flood() -> void:
	var service: ServerMatchService = ServerMatchServiceScript.new()
	add_child(service)

	var config := MatchStartCoordinatorScript.new().build_server_canonical_config(
		_make_room_snapshot(),
		"127.0.0.1",
		9000,
		1
	)
	config.match_duration_ticks = 120
	assert_true(bool(service.commit_prepared_match(config).get("ok", false)))

	for _i in range(3):
		service._process(1.0)
		assert_eq(int(service.get_tick_budget_metrics().get("ticks_this_process", -1)), 0)
		assert_eq(int(service.get_tick_budget_metrics().get("phase", -1)), ServerMatchService.PHASE_WAITING_READY)

	for peer_id in [1, 2]:
		service.ingest_runtime_message({
			"message_type": TransportMessageTypesScript.OPENING_SNAPSHOT_ACK,
			"sender_peer_id": peer_id,
			"peer_id": peer_id,
		})
	service._process(1.0)
	assert_eq(int(service.get_tick_budget_metrics().get("phase", -1)), ServerMatchService.PHASE_RUNNING)
	service._process(1.0)
	assert_eq(int(service.get_tick_budget_metrics().get("ticks_this_process", -1)), 0)

	service._process(TickRunnerScript.TICK_DT * 60.0)
	assert_true(int(service.get_tick_budget_metrics().get("ticks_this_process", 0)) <= ServerMatchService.MAX_AUTHORITY_TICKS_PER_FRAME)

	service.shutdown_match()
	service.queue_free()


func _make_room_snapshot() -> RoomSnapshot:
	var snapshot := RoomSnapshot.new()
	snapshot.room_id = "opening_snapshot_barrier_room"
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
	host.team_id = 1
	snapshot.members.append(host)

	var client := RoomMemberState.new()
	client.peer_id = 2
	client.player_name = "Client"
	client.ready = true
	client.slot_index = 1
	client.character_id = "hero_2"
	client.team_id = 2
	snapshot.members.append(client)
	return snapshot
