extends Node

const AppRuntimeRootScript = preload("res://app/flow/app_runtime_root.gd")
const BattleSessionAdapterScript = preload("res://network/session/battle_session_adapter.gd")


func _ready() -> void:
	run_all()


func run_all() -> void:
	_test_battle_root_unregister_clears_runtime_references()
	_test_battle_session_shutdown_clears_runtime_metrics()
	_test_battle_root_stays_single_scene_across_re_registration()


func _test_battle_root_unregister_clears_runtime_references() -> void:
	var runtime: Node = AppRuntimeRootScript.new()
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
	var settlement := SettlementController.new()
	settlement.name = "SettlementController"
	bootstrap.add_child(bridge)
	battle_scene.add_child(bootstrap)
	battle_scene.add_child(hud)
	battle_scene.add_child(camera)
	battle_scene.add_child(settlement)
	add_child(battle_scene)

	runtime.register_battle_modules(battle_scene, bootstrap, bridge, hud, camera, settlement)
	runtime.unregister_battle_modules(battle_scene)
	var dump: Dictionary = runtime.debug_dump_runtime_structure()
	_assert_true(not bool(dump.get("has_active_battle_scene", true)), "runtime unregister clears active battle scene reference")
	_assert_true(not bool(dump.get("has_active_battle_bootstrap", true)), "runtime unregister clears bootstrap reference")
	_assert_true(not bool(dump.get("has_active_presentation_bridge", true)), "runtime unregister clears bridge reference")
	_assert_true(not bool(dump.get("has_active_settlement", true)), "runtime unregister clears settlement reference")

	battle_scene.free()
	runtime.free()


func _test_battle_session_shutdown_clears_runtime_metrics() -> void:
	var adapter = BattleSessionAdapterScript.new()
	add_child(adapter)
	adapter.setup_from_start_config(_make_config())
	adapter.start_battle()
	adapter.advance_authoritative_tick({"move_x": 1, "action_place": true})
	adapter.shutdown_battle()
	var metrics: Dictionary = adapter.build_runtime_metrics_snapshot()
	_assert_true(int(metrics.get("rollback_count", -1)) == 0, "shutdown clears rollback count in metrics")
	_assert_true(int(metrics.get("pending_server_messages", -1)) == 0, "shutdown clears delayed transport queue")
	_assert_true(int(metrics.get("ack_tick", -1)) == 0, "shutdown clears ack tick")
	_assert_true(int(metrics.get("authoritative_tick", -1)) == 0, "shutdown clears authoritative tick in snapshot")
	_assert_true(bool(metrics.get("shutdown_complete", false)), "shutdown metrics report cleanup complete")
	adapter.free()


func _test_battle_root_stays_single_scene_across_re_registration() -> void:
	var runtime: Node = AppRuntimeRootScript.new()
	add_child(runtime)
	runtime.initialize_runtime()

	var first_scene := Node2D.new()
	first_scene.name = "BattleMain"
	var first_bootstrap := BattleBootstrap.new()
	first_bootstrap.name = "BattleBootstrap"
	var first_bridge := BattlePresentationBridge.new()
	first_bridge.name = "PresentationBridge"
	var first_hud := BattleHudController.new()
	first_hud.name = "BattleHudController"
	var first_camera := BattleCameraController.new()
	first_camera.name = "BattleCameraController"
	var first_settlement := SettlementController.new()
	first_settlement.name = "SettlementController"
	first_bootstrap.add_child(first_bridge)
	first_scene.add_child(first_bootstrap)
	first_scene.add_child(first_hud)
	first_scene.add_child(first_camera)
	first_scene.add_child(first_settlement)
	add_child(first_scene)
	runtime.register_battle_modules(first_scene, first_bootstrap, first_bridge, first_hud, first_camera, first_settlement)
	runtime.unregister_battle_modules(first_scene)
	first_scene.free()

	var second_scene := Node2D.new()
	second_scene.name = "BattleMain"
	var second_bootstrap := BattleBootstrap.new()
	second_bootstrap.name = "BattleBootstrap"
	var second_bridge := BattlePresentationBridge.new()
	second_bridge.name = "PresentationBridge"
	var second_hud := BattleHudController.new()
	second_hud.name = "BattleHudController"
	var second_camera := BattleCameraController.new()
	second_camera.name = "BattleCameraController"
	var second_settlement := SettlementController.new()
	second_settlement.name = "SettlementController"
	second_bootstrap.add_child(second_bridge)
	second_scene.add_child(second_bootstrap)
	second_scene.add_child(second_hud)
	second_scene.add_child(second_camera)
	second_scene.add_child(second_settlement)
	add_child(second_scene)
	runtime.register_battle_modules(second_scene, second_bootstrap, second_bridge, second_hud, second_camera, second_settlement)

	var dump: Dictionary = runtime.debug_dump_runtime_structure()
	_assert_true(not bool(dump.get("battle_root_has_multiple_scenes", true)), "battle root keeps a single live battle scene registration")
	_assert_true(int(dump.get("battle_root_children", 0)) == 1, "battle root child count stays at one live battle scene")

	second_scene.free()
	runtime.free()


func _make_config() -> BattleStartConfig:
	var config := BattleStartConfig.new()
	config.room_id = "phase3_cleanup_room"
	config.match_id = "phase3_cleanup_match"
	config.map_id = "default_map"
	config.rule_set_id = "classic"
	config.seed = 20260329
	config.start_tick = 0
	config.players = [
		{"peer_id": 1, "player_name": "P1", "slot_index": 0, "spawn_slot": 0, "character_id": "hero_1"},
		{"peer_id": 2, "player_name": "P2", "slot_index": 1, "spawn_slot": 1, "character_id": "hero_2"},
	]
	config.sort_players()
	return config


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		print("[PASS] %s" % message)
		return
	push_error("[FAIL] %s" % message)
