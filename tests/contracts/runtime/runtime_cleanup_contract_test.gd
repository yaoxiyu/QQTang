extends "res://tests/gut/base/qqt_contract_test.gd"

const AppRuntimeRootScript = preload("res://app/flow/app_runtime_root.gd")
const BattleSessionAdapterScript = preload("res://network/session/battle_session_adapter.gd")
const MapCatalogScript = preload("res://content/maps/catalog/map_catalog.gd")
const ModeCatalogScript = preload("res://content/modes/catalog/mode_catalog.gd")
const RuleSetCatalogScript = preload("res://content/rulesets/catalog/rule_set_catalog.gd")
const RuntimeLifecycleStateScript = preload("res://app/flow/runtime_lifecycle_state.gd")


var _runtime_disposing_seen: bool = false
var _runtime_disposed_seen: bool = false
var _runtime_last_state_seen: int = RuntimeLifecycleStateScript.Value.NONE


func test_main() -> void:
	await _main_body()


func _main_body() -> void:
	_test_battle_root_unregister_clears_runtime_references()
	_test_battle_session_shutdown_clears_runtime_metrics()
	_test_battle_root_stays_single_scene_across_re_registration()
	await _test_runtime_exit_tree_reports_disposed_lifecycle()


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


func _test_runtime_exit_tree_reports_disposed_lifecycle() -> void:
	var runtime: Node = AppRuntimeRootScript.new()
	_runtime_disposing_seen = false
	_runtime_disposed_seen = false
	_runtime_last_state_seen = RuntimeLifecycleStateScript.Value.NONE
	add_child(runtime)
	runtime.initialize_runtime()
	if runtime.has_signal("runtime_disposing"):
		runtime.runtime_disposing.connect(_on_runtime_disposing_observed.bind(runtime))
	if runtime.has_signal("runtime_disposed"):
		runtime.runtime_disposed.connect(_on_runtime_disposed_observed.bind(runtime))

	remove_child(runtime)
	await get_tree().process_frame

	_assert_true(_runtime_disposing_seen, "runtime cleanup emits runtime_disposing")
	_assert_true(_runtime_disposed_seen, "runtime cleanup emits runtime_disposed")
	_assert_true(int(_runtime_last_state_seen) == int(RuntimeLifecycleStateScript.Value.DISPOSED), "runtime lifecycle enters DISPOSED on exit_tree")
	_assert_true(not runtime.is_runtime_ready(), "runtime cleanup does not leave ready state behind")
	runtime.free()


func _make_config() -> BattleStartConfig:
	var config := BattleStartConfig.new()
	var default_mode_id := ModeCatalogScript.get_default_mode_id()
	config.room_id = "cleanup_contract_room"
	config.match_id = "cleanup_contract_match"
	config.map_id = MapCatalogScript.get_default_map_id()
	config.mode_id = default_mode_id
	config.rule_set_id = RuleSetCatalogScript.get_default_rule_id()
	config.battle_seed = 20260329
	config.start_tick = 0
	config.match_duration_ticks = 10
	config.players = [
		{"peer_id": 1, "player_name": "P1", "slot_index": 0, "spawn_slot": 0, "character_id": "hero_1"},
		{"peer_id": 2, "player_name": "P2", "slot_index": 1, "spawn_slot": 1, "character_id": "hero_2"},
	]
	config.sort_players()
	return config


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		return


func _on_runtime_disposing_observed(runtime: Node) -> void:
	_runtime_disposing_seen = true
	_runtime_last_state_seen = int(runtime.runtime_lifecycle_state)


func _on_runtime_disposed_observed(runtime: Node) -> void:
	_runtime_disposed_seen = true
	_runtime_last_state_seen = int(runtime.runtime_lifecycle_state)


