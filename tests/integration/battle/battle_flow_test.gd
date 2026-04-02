extends Node

const AppRuntimeRootScript = preload("res://app/flow/app_runtime_root.gd")
const FrontFlowControllerScript = preload("res://app/flow/front_flow_controller.gd")
const RoomSessionControllerScript = preload("res://network/session/room_session_controller.gd")
const BattleSessionAdapterScript = preload("res://network/session/battle_session_adapter.gd")
const BattleStartConfigScript = preload("res://gameplay/battle/config/battle_start_config.gd")
const BattleSimConfigBuilderScript = preload("res://gameplay/battle/config/battle_sim_config_builder.gd")
const MapLoaderScript = preload("res://content/maps/runtime/map_loader.gd")
const RuleCatalogScript = preload("res://content/rules/rule_catalog.gd")
const CharacterCatalogScript = preload("res://content/characters/catalog/character_catalog.gd")


func _ready() -> void:
	run_all()


func run_all() -> void:
	_test_battle_bootstrap_debug_dump_tracks_runtime()
	_test_battle_bootstrap_does_not_bridge_settlement_flow()
	_test_shutdown_battle_clears_runtime_without_mutating_room_state()
	_test_app_root_battle_root_tracks_live_battle_modules()
	_test_item_spawn_system_spawns_from_destroyed_breakable()
	_test_battle_session_adapter_finishes_by_time_limit()
	_test_battle_session_adapter_cycles_network_profiles()
	_test_battle_session_adapter_forced_divergence_triggers_rollback()


func _test_battle_bootstrap_debug_dump_tracks_runtime() -> void:
	var bootstrap := BattleBootstrap.new()
	var bridge := BattlePresentationBridge.new()
	var hud := BattleHudController.new()

	add_child(bootstrap)
	add_child(bridge)
	add_child(hud)

	bootstrap.presentation_bridge = bridge
	bootstrap.battle_hud_controller = hud

	var context := BattleContext.new()
	context.sim_world = SimWorld.new()
	context.tick_runner = context.sim_world.tick_runner
	context.rollback_controller = RollbackController.new()

	bootstrap.bind_context(context)
	var dump := bootstrap.debug_dump_context()

	_assert_true(bool(dump.get("has_context", false)), "battle bootstrap debug dump reports context")
	_assert_true(bool(dump.get("has_runtime", false)), "battle bootstrap debug dump reports runtime")
	_assert_true(bool(dump.get("rollback_listener_connected", false)), "battle bootstrap connects rollback listener")
	_assert_true(dump.has("bridge"), "battle bootstrap debug dump embeds bridge summary")
	_assert_true(dump.has("hud"), "battle bootstrap debug dump embeds hud summary")

	bootstrap.release_context()
	context.clear_runtime_refs()
	bootstrap.free()
	bridge.free()
	hud.free()


func _test_battle_bootstrap_does_not_bridge_settlement_flow() -> void:
	var bootstrap := BattleBootstrap.new()
	var bridge := BattlePresentationBridge.new()
	var hud := BattleHudController.new()
	var settlement_anchor := Control.new()
	var settlement := SettlementController.new()
	var flow = FrontFlowControllerScript.new()
	var result_label := Label.new()
	result_label.name = "ResultLabel"
	var detail_label := Label.new()
	detail_label.name = "DetailLabel"
	var counters := {"return_count": 0}

	settlement.name = "SettlementController"
	settlement.add_child(result_label)
	settlement.add_child(detail_label)
	settlement_anchor.add_child(settlement)

	add_child(bootstrap)
	add_child(bridge)
	add_child(hud)
	add_child(settlement_anchor)
	add_child(flow)

	bootstrap.presentation_bridge = bridge
	bootstrap.battle_hud_controller = hud

	var context := BattleContext.new()
	context.sim_world = SimWorld.new()
	context.tick_runner = context.sim_world.tick_runner
	context.rollback_controller = RollbackController.new()
	bootstrap.bind_context(context)

	settlement.return_to_room_requested.connect(func() -> void:
		counters["return_count"] = int(counters.get("return_count", 0)) + 1
	)

	flow.enter_room()
	flow.request_start_match()
	flow.on_loading_completed()
	flow.on_battle_finished(BattleResult.new())
	settlement.request_return_to_room()

	var before_release := bootstrap.debug_dump_context()
	_assert_true(int(counters.get("return_count", 0)) == 1, "settlement emits one return signal")
	_assert_true(bool(before_release.get("has_runtime", false)), "battle bootstrap keeps runtime until flow layer releases it")
	_assert_true(flow.is_in_state(FrontFlowControllerScript.FlowState.SETTLEMENT), "battle bootstrap does not mutate front flow during settlement return")

	bootstrap.release_context()
	context.clear_runtime_refs()
	var after_release := bootstrap.debug_dump_context()
	_assert_true(not bool(after_release.get("has_runtime", true)), "flow layer can release battle bootstrap explicitly")

	bootstrap.free()
	bridge.free()
	hud.free()
	settlement_anchor.free()
	flow.free()


func _test_shutdown_battle_clears_runtime_without_mutating_room_state() -> void:
	var bootstrap := BattleBootstrap.new()
	var bridge := BattlePresentationBridge.new()
	var hud := BattleHudController.new()
	var settlement_anchor := Control.new()
	var settlement := SettlementController.new()
	var result_label := Label.new()
	result_label.name = "ResultLabel"
	var detail_label := Label.new()
	detail_label.name = "DetailLabel"

	settlement.name = "SettlementController"
	settlement.add_child(result_label)
	settlement.add_child(detail_label)
	settlement_anchor.add_child(settlement)

	add_child(bootstrap)
	add_child(bridge)
	add_child(hud)
	add_child(settlement_anchor)

	bootstrap.presentation_bridge = bridge
	bootstrap.battle_hud_controller = hud

	var room_controller = RoomSessionControllerScript.new()
	add_child(room_controller)
	room_controller.create_room(1)
	room_controller.join_room(_make_member(2, true))
	room_controller.set_member_ready(1, true)

	var context := BattleContext.new()
	context.sim_world = SimWorld.new()
	context.tick_runner = context.sim_world.tick_runner
	context.rollback_controller = RollbackController.new()
	bootstrap.bind_context(context)

	var result := BattleResult.new()
	result.local_peer_id = 1
	result.winner_peer_ids = [1]
	result.finish_reason = "test"
	result.finish_tick = 100
	settlement.show_result(result)

	bridge.shutdown_bridge()
	hud.reset_hud()
	settlement.reset_settlement()
	bootstrap.release_context()
	context.clear_runtime_refs()

	var dump := bootstrap.debug_dump_context()
	var room_dump := room_controller.debug_dump_room()
	var room_snapshot: Dictionary = room_dump.get("snapshot", {})
	_assert_true(not bool(dump.get("has_runtime", true)), "battle shutdown clears runtime references")
	_assert_true(not settlement.visible, "battle shutdown hides settlement")
	_assert_true(bool(room_snapshot.get("all_ready", false)), "battle bootstrap release leaves room state untouched")
	_assert_true(context.sim_world == null and context.client_session == null and context.server_session == null, "battle shutdown clears battle context runtime pointers")

	bootstrap.free()
	bridge.free()
	hud.free()
	settlement_anchor.free()
	room_controller.free()


func _test_app_root_battle_root_tracks_live_battle_modules() -> void:
	var runtime = AppRuntimeRootScript.new()
	add_child(runtime)
	runtime.initialize_runtime()

	var battle_scene := Node2D.new()
	battle_scene.name = "BattleMain"
	var bootstrap := BattleBootstrap.new()
	bootstrap.name = "BattleBootstrap"
	var bridge := BattlePresentationBridge.new()
	bridge.name = "PresentationBridge"
	var hud := BattleHudController.new()
	hud.name = "BattleHudController"
	var camera := BattleCameraController.new()
	camera.name = "BattleCameraController"
	var settlement_anchor := Control.new()
	settlement_anchor.name = "SettlementPopupAnchor"
	var settlement := SettlementController.new()
	settlement.name = "SettlementController"
	settlement_anchor.add_child(settlement)
	bootstrap.add_child(bridge)
	battle_scene.add_child(bootstrap)
	battle_scene.add_child(hud)
	battle_scene.add_child(camera)
	battle_scene.add_child(settlement_anchor)
	add_child(battle_scene)

	runtime.register_battle_modules(battle_scene, bootstrap, bridge, hud, camera, settlement)

	_assert_true(runtime.battle_root.has_node("BattleMain"), "battle root carries live battle scene")
	_assert_true(runtime.battle_root.has_node("BattleMain/BattleBootstrap"), "battle root carries live bootstrap module")
	_assert_true(runtime.battle_root.has_node("BattleMain/BattleBootstrap/PresentationBridge"), "battle root carries live presentation bridge module")
	_assert_true(runtime.battle_root.has_node("BattleMain/BattleHudController"), "battle root carries live hud module")
	_assert_true(runtime.battle_root.has_node("BattleMain/BattleCameraController"), "battle root carries live camera module")
	_assert_true(runtime.battle_root.has_node("BattleMain/SettlementPopupAnchor/SettlementController"), "battle root carries live settlement module")

	runtime.unregister_battle_modules(battle_scene)
	_assert_true(runtime.current_battle_scene == null, "battle root unregister clears live battle scene reference")
	_assert_true(runtime.current_battle_bootstrap == null, "battle root unregister clears live bootstrap reference")

	battle_scene.queue_free()
	runtime.queue_free()


func _test_item_spawn_system_spawns_from_destroyed_breakable() -> void:
	var world := SimWorld.new()
	world.bootstrap(SimConfig.new(), {"grid": BuiltinMapFactory.build_basic_map()})
	var ctx := SimContext.new()
	ctx.state = world.state
	ctx.queries = world.queries
	ctx.events = world.events
	ctx.tick = 12
	ctx.rng = SimRng.new(20260402)
	var sim_config := BattleSimConfigBuilderScript.new().build_for_start_config(_make_adapter_config("battle_flow_item_spawn_match", 20260402))
	sim_config.system_flags["item_drop_profile"] = {
		"profile_id": "test_guaranteed_single_spawn",
		"drop_enabled": true,
		"brick_drop_mode": "weighted_random",
		"max_spawn_per_match": 999,
		"empty_weight": 0,
		"drop_pool": [
			{
				"item_id": "power_up",
				"item_type": 1,
				"display_name": "Power Up",
				"pickup_effect_type": "modify_bomb_range",
				"weight": 1,
			},
		],
	}
	ctx.config = sim_config

	var destroyed_event := SimEvent.new(ctx.tick, SimEvent.EventType.CELL_DESTROYED)
	destroyed_event.payload = {
		"cell_x": 4,
		"cell_y": 1,
		"can_spawn_item": true,
	}
	ctx.events.push(destroyed_event)

	var system := preload("res://gameplay/simulation/systems/item_spawn_system.gd").new()
	system.execute(ctx)

	var spawned_count: int = world.state.items.active_ids.size()
	var spawned_event_found := false
	for event in world.events.get_events():
		if event != null and int(event.event_type) == SimEvent.EventType.ITEM_SPAWNED:
			spawned_event_found = true
			break

	_assert_true(spawned_count == 1, "item spawn system creates item from destroyed breakable block")
	_assert_true(spawned_event_found, "item spawn system emits item spawned event")
	world.dispose()


func _test_battle_session_adapter_finishes_by_time_limit() -> void:
	var adapter = BattleSessionAdapterScript.new()
	add_child(adapter)

	var config := _make_adapter_config("battle_adapter_match", 20260328)
	adapter.setup_from_start_config(config)
	adapter.use_remote_debug_inputs = false
	_assert_true(adapter.get_lifecycle_state_name() == "IDLE", "battle session adapter enters idle after setup")

	var finished_box := {"result": null}
	adapter.battle_finished_authoritatively.connect(func(result) -> void:
		finished_box["result"] = result
	)

	adapter.start_battle()
	_assert_true(adapter.get_lifecycle_state_name() == "RUNNING", "battle session adapter enters running after start")
	for _tick in range(BattleSessionAdapterScript.DEFAULT_MATCH_DURATION_TICKS + 2):
		adapter.advance_authoritative_tick({})
		if finished_box["result"] != null:
			break

	var finished_result = finished_box["result"]
	_assert_true(finished_result != null, "battle session adapter emits authoritative finish result")
	_assert_true(finished_result != null and finished_result.finish_reason == "time_up", "battle session adapter ends match by time limit")
	_assert_true(finished_result != null and finished_result.finish_tick > 0, "battle session adapter reports finish tick")
	_assert_true(adapter.get_lifecycle_state_name() == "FINISHING", "battle session adapter enters finishing after authoritative end")

	adapter.shutdown_battle()
	_assert_true(adapter.get_lifecycle_state_name() == "STOPPED", "battle session adapter enters stopped after shutdown")
	_assert_true(adapter.is_shutdown_complete(), "battle session adapter reports shutdown complete after shutdown")
	adapter.free()


func _test_battle_session_adapter_cycles_network_profiles() -> void:
	var adapter = BattleSessionAdapterScript.new()
	add_child(adapter)

	var initial_latency: int = adapter.get_latency_profile_ms()
	var cycled_latency: int = adapter.cycle_latency_profile()
	var initial_loss: int = adapter.get_packet_loss_percent()
	var cycled_loss: int = adapter.cycle_loss_profile()

	_assert_true(cycled_latency != initial_latency, "battle session adapter cycles latency profile")
	_assert_true(cycled_loss != initial_loss, "battle session adapter cycles packet loss profile")
	_assert_true(not adapter.get_network_profile_summary().is_empty(), "battle session adapter exposes network profile summary")

	adapter.free()


func _test_battle_session_adapter_forced_divergence_triggers_rollback() -> void:
	var adapter = BattleSessionAdapterScript.new()
	add_child(adapter)

	var config := _make_adapter_config("battle_divergence_match", 20260329)
	adapter.setup_from_start_config(config)
	adapter.use_remote_debug_inputs = false
	adapter.cycle_latency_profile()
	adapter.start_battle()
	adapter.arm_force_prediction_divergence()

	var corrected := false
	var resynced := false
	var metrics: Dictionary = {}
	adapter.prediction_debug_event.connect(func(event: Dictionary) -> void:
		var event_type := str(event.get("type", ""))
		if event_type == "prediction_corrected":
			corrected = true
		elif event_type == "full_resync":
			resynced = true
	)

	for _tick in range(40):
		adapter.advance_authoritative_tick({"move_x": 1})
		metrics = adapter.build_runtime_metrics_snapshot()
		if corrected or resynced or int(metrics.get("rollback_count", 0)) > 0 or int(metrics.get("correction_count", 0)) > 0 or int(metrics.get("resync_count", 0)) > 0:
			break

	_assert_true(int(metrics.get("rollback_count", 0)) > 0 or int(metrics.get("resync_count", 0)) > 0, "forced divergence triggers rollback or resync path")
	_assert_true(int(metrics.get("correction_count", 0)) > 0 or corrected or resynced or int(metrics.get("last_resync_tick", -1)) >= 0, "forced divergence exposes correction or resync evidence")
	_assert_true(not str(metrics.get("last_correction", "")).is_empty() or int(metrics.get("last_resync_tick", -1)) >= 0, "forced divergence records correction summary or resync tick")

	adapter.shutdown_battle()
	adapter.free()


func _make_member(peer_id: int, ready: bool) -> RoomMemberState:
	var member := RoomMemberState.new()
	member.peer_id = peer_id
	member.player_name = "Player%d" % peer_id
	member.ready = ready
	member.slot_index = peer_id - 1
	member.character_id = "hero_default" if peer_id == 1 else "hero_runner"
	return member


func _make_adapter_config(match_id: String, seed: int) -> BattleStartConfig:
	var metadata := MapLoaderScript.load_map_metadata("default_map")
	var rule_metadata := RuleCatalogScript.get_rule_metadata("classic")
	var host_character_metadata := CharacterCatalogScript.get_character_metadata("hero_default")
	var client_character_metadata := CharacterCatalogScript.get_character_metadata("hero_runner")
	var spawn_points: Array = metadata.get("spawn_points", [])
	var config := BattleStartConfigScript.new()
	config.protocol_version = BattleStartConfigScript.DEFAULT_PROTOCOL_VERSION
	config.gameplay_rule_version = int(rule_metadata.get("version", BattleStartConfigScript.DEFAULT_GAMEPLAY_RULE_VERSION))
	config.build_mode = BattleStartConfigScript.BUILD_MODE_CANDIDATE
	config.room_id = "battle_adapter_room"
	config.match_id = match_id
	config.map_id = "default_map"
	config.map_version = int(metadata.get("version", 1))
	config.map_content_hash = String(metadata.get("content_hash", ""))
	config.rule_set_id = "classic"
	config.battle_seed = seed
	config.start_tick = 0
	config.item_spawn_profile_id = String(metadata.get("item_spawn_profile_id", "default_items"))
	config.session_mode = "singleplayer_local"
	config.topology = "listen"
	config.local_peer_id = 1
	config.controlled_peer_id = 1
	config.owner_peer_id = 1
	config.player_slots = [
		{
			"peer_id": 1,
			"player_name": "P1",
			"slot_index": 0,
			"spawn_slot": 0,
			"character_id": "hero_default",
		},
		{
			"peer_id": 2,
			"player_name": "P2",
			"slot_index": 1,
			"spawn_slot": 1,
			"character_id": "hero_runner",
		},
	]
	config.players = config.player_slots.duplicate(true)
	config.character_loadouts = [
		{
			"peer_id": 1,
			"character_id": "hero_default",
			"content_hash": String(host_character_metadata.get("content_hash", "")),
		},
		{
			"peer_id": 2,
			"character_id": "hero_runner",
			"content_hash": String(client_character_metadata.get("content_hash", "")),
		},
	]
	config.spawn_assignments = [
		{
			"peer_id": 1,
			"slot_index": 0,
			"spawn_index": 0,
			"spawn_cell_x": spawn_points[0].x,
			"spawn_cell_y": spawn_points[0].y,
		},
		{
			"peer_id": 2,
			"slot_index": 1,
			"spawn_index": 1,
			"spawn_cell_x": spawn_points[1].x,
			"spawn_cell_y": spawn_points[1].y,
		},
	]
	config.sort_players()
	return config


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		print("[PASS] %s" % message)
		return
	push_error("[FAIL] %s" % message)
