extends Node

const FrontFlowControllerScript = preload("res://app/flow/front_flow_controller.gd")
const RoomSessionControllerScript = preload("res://network/session/room_session_controller.gd")
const MatchStartCoordinatorScript = preload("res://network/session/match_start_coordinator.gd")


func _ready() -> void:
	run_all()


func run_all() -> void:
	_test_run_two_matches_in_sequence()
	_test_run_five_matches_in_sequence()
	_test_run_ten_matches_in_sequence()
	_test_context_is_recreated_each_match()
	_test_actor_count_returns_to_zero_after_shutdown()


func _test_run_two_matches_in_sequence() -> void:
	var summary := _run_match_sequence(2)
	_assert_true(int(summary.get("completed_matches", 0)) == 2, "two-match sequence completes")
	_assert_true(int(summary.get("return_signal_count", -1)) == 2, "two-match sequence emits one return signal per match")
	_assert_true(String(summary.get("final_flow_state", "")) == "ROOM", "two-match sequence returns flow to room")


func _test_run_five_matches_in_sequence() -> void:
	var summary := _run_match_sequence(5)
	_assert_true(int(summary.get("completed_matches", 0)) == 5, "five-match sequence completes")
	_assert_true(int(summary.get("return_signal_count", -1)) == 5, "five-match sequence keeps callbacks single-fired")
	_assert_true(int(summary.get("remaining_fx_nodes", -1)) == 0, "five-match sequence clears fx nodes after shutdown")


func _test_run_ten_matches_in_sequence() -> void:
	var summary := _run_match_sequence(10)
	_assert_true(int(summary.get("completed_matches", 0)) == 10, "ten-match sequence completes")
	_assert_true(int(summary.get("return_signal_count", -1)) == 10, "ten-match sequence avoids duplicate shutdown callbacks")
	_assert_true(int(summary.get("remaining_actor_nodes", -1)) == 0, "ten-match sequence leaves no actor nodes behind")


func _test_context_is_recreated_each_match() -> void:
	var summary := _run_match_sequence(3)
	var context_ids: Array = summary.get("context_ids", [])
	var unique_ids: Dictionary = {}
	for context_id in context_ids:
		unique_ids[int(context_id)] = true
	_assert_true(unique_ids.size() == context_ids.size(), "battle context is recreated for each match")


func _test_actor_count_returns_to_zero_after_shutdown() -> void:
	var summary := _run_match_sequence(1)
	_assert_true(int(summary.get("remaining_actor_nodes", -1)) == 0, "actor layer returns to zero children after shutdown")
	_assert_true(int(summary.get("remaining_fx_nodes", -1)) == 0, "fx layer returns to zero children after shutdown")
	_assert_true(not bool(summary.get("settlement_visible", true)), "settlement stays hidden after shutdown")


func _run_match_sequence(match_count: int) -> Dictionary:
	var flow = FrontFlowControllerScript.new()
	var bootstrap := BattleBootstrap.new()
	var bridge := BattlePresentationBridge.new()
	var hud := BattleHudController.new()
	var actor_layer := Node2D.new()
	var fx_layer := Node2D.new()
	var settlement_anchor := Control.new()
	var settlement := SettlementController.new()
	var countdown := CountdownPanel.new()
	var player_panel := PlayerStatusPanel.new()
	var network_panel := NetworkStatusPanel.new()
	var message_panel := MatchMessagePanel.new()
	var room_controller = RoomSessionControllerScript.new()
	var coordinator = MatchStartCoordinatorScript.new()
	var counters := {"return_signal_count": 0}
	var context_ids: Array[int] = []

	countdown.name = "CountdownPanel"
	player_panel.name = "PlayerStatusPanel"
	network_panel.name = "NetworkStatusPanel"
	message_panel.name = "MatchMessagePanel"
	settlement.name = "SettlementController"
	actor_layer.name = "ActorLayer"
	fx_layer.name = "FxLayer"
	settlement_anchor.name = "SettlementPopupAnchor"

	var result_label := Label.new()
	result_label.name = "ResultLabel"
	var detail_label := Label.new()
	detail_label.name = "DetailLabel"
	settlement.add_child(result_label)
	settlement.add_child(detail_label)
	settlement_anchor.add_child(settlement)

	add_child(flow)
	add_child(bootstrap)
	add_child(bridge)
	add_child(hud)
	add_child(actor_layer)
	add_child(fx_layer)
	add_child(countdown)
	add_child(player_panel)
	add_child(network_panel)
	add_child(message_panel)
	add_child(settlement_anchor)
	add_child(room_controller)
	add_child(coordinator)

	bridge.actor_layer = actor_layer
	bridge.fx_layer = fx_layer
	bridge.actor_registry = BattleActorRegistry.new()
	bridge.state_to_view_mapper = BattleStateToViewMapper.new()
	bridge.battle_event_router = BattleEventRouter.new()
	bridge.add_child(bridge.battle_event_router)
	bridge.battle_event_router.explosion_event_routed.connect(bridge._on_explosion_event_routed)

	hud.countdown_panel = countdown
	hud.player_status_panel = player_panel
	hud.network_status_panel = network_panel
	hud.match_message_panel = message_panel

	bootstrap.presentation_bridge = bridge
	bootstrap.battle_hud_controller = hud
	settlement.return_to_room_requested.connect(func() -> void:
		counters["return_signal_count"] = int(counters.get("return_signal_count", 0)) + 1
	)

	room_controller.create_room(1)
	room_controller.join_room(_make_member(2, true))
	room_controller.set_room_selection("basic_map", "classic")
	coordinator.match_id_prefix = "multi_match_chain"
	coordinator.forced_seed = 20260328

	flow.enter_room()

	for match_index in range(match_count):
		room_controller.set_member_ready(1, true)
		room_controller.set_member_ready(2, true)
		var snapshot: RoomSnapshot = room_controller.build_room_snapshot()
		var start_config: BattleStartConfig = coordinator.build_start_config(snapshot)
		var context := _make_context(match_index, start_config)
		context_ids.append(context.get_instance_id())

		bootstrap.bind_context(context)
		_seed_runtime_views(bridge, hud, context.sim_world, match_index)

		flow.request_start_match()
		flow.on_loading_completed()

		var result := BattleResult.new()
		result.local_peer_id = 1
		result.winner_peer_ids = [1]
		result.finish_reason = "sequence_%d" % match_index
		result.finish_tick = 100 + match_index
		flow.on_battle_finished(result)
		settlement.show_result(result)
		settlement.request_return_to_room()
		_shutdown_active_battle(bootstrap, bridge, hud, settlement, context)
		flow.return_to_room()
		flow.on_return_to_room_completed()

	var summary := {
		"completed_matches": match_count,
		"return_signal_count": int(counters.get("return_signal_count", 0)),
		"final_flow_state": String(flow.get_state_name()),
		"context_ids": context_ids,
		"remaining_actor_nodes": actor_layer.get_child_count(),
		"remaining_fx_nodes": fx_layer.get_child_count(),
		"settlement_visible": settlement.visible,
	}

	flow.queue_free()
	bootstrap.queue_free()
	bridge.queue_free()
	hud.queue_free()
	actor_layer.queue_free()
	fx_layer.queue_free()
	countdown.queue_free()
	player_panel.queue_free()
	network_panel.queue_free()
	message_panel.queue_free()
	settlement_anchor.queue_free()
	room_controller.queue_free()
	coordinator.queue_free()
	return summary


func _make_context(match_index: int, start_config: BattleStartConfig) -> BattleContext:
	var context := BattleContext.new()
	context.battle_start_config = start_config.duplicate_deep()
	context.sim_world = _make_test_world(match_index)
	context.tick_runner = context.sim_world.tick_runner
	context.rollback_controller = RollbackController.new()
	return context


func _make_test_world(match_index: int) -> SimWorld:
	var world := SimWorld.new()
	world.state.match_state.tick = 30 + match_index
	world.state.match_state.remaining_ticks = 120 - match_index

	var player_a_id := world.state.players.add_player(0, 0, 1, 1)
	var player_b_id := world.state.players.add_player(1, 1, 3, 3)
	var player_a := world.state.players.get_player(player_a_id)
	var player_b := world.state.players.get_player(player_b_id)
	player_a.facing = PlayerState.FacingDir.RIGHT
	player_b.facing = PlayerState.FacingDir.LEFT

	var bubble_id := world.state.bubbles.spawn_bubble(player_a_id, 2, 2, 2, 40)
	var bubble := world.state.bubbles.get_bubble(bubble_id)
	bubble.owner_player_id = player_a_id

	var item_id := world.state.items.spawn_item(1 + (match_index % 3), 4, 4)
	var item := world.state.items.get_item(item_id)
	item.visible = true

	return world


func _seed_runtime_views(bridge: BattlePresentationBridge, hud: BattleHudController, world: SimWorld, match_index: int) -> void:
	var exploded_event := SimEvent.new(30 + match_index, SimEvent.EventType.BUBBLE_EXPLODED)
	exploded_event.payload["covered_cells"] = [Vector2i(2, 2), Vector2i(3, 2)]
	bridge.consume_tick_result({}, world, [exploded_event])
	hud.consume_battle_state(world)
	hud.consume_network_metrics({
		"latency_ms": 33 + match_index,
		"ack_tick": 20 + match_index,
		"rollback_count": match_index % 2,
		"predicted_tick": 21 + match_index,
		"snapshot_tick": 20 + match_index,
	})


func _shutdown_active_battle(
	bootstrap: BattleBootstrap,
	bridge: BattlePresentationBridge,
	hud: BattleHudController,
	settlement: SettlementController,
	context: BattleContext
) -> void:
	bridge.shutdown_bridge()
	hud.reset_hud()
	settlement.reset_settlement()
	bootstrap.release_context()
	context.clear_runtime_refs()


func _make_member(peer_id: int, ready: bool) -> RoomMemberState:
	var member := RoomMemberState.new()
	member.peer_id = peer_id
	member.player_name = "Player%d" % peer_id
	member.ready = ready
	member.slot_index = peer_id - 1
	member.character_id = "hero_%d" % peer_id
	return member


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		print("[PASS] %s" % message)
		return
	push_error("[FAIL] %s" % message)
