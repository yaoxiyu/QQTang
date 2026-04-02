extends Node

const AppRuntimeRootScript = preload("res://app/flow/app_runtime_root.gd")
const BattleSessionAdapterScript = preload("res://network/session/battle_session_adapter.gd")


func _ready() -> void:
	run_all()


func run_all() -> void:
	_test_battle_session_adapter_lifecycle_transitions()
	_test_shutdown_resets_runtime_metrics_and_debug_state()
	_test_app_root_dump_reports_battle_lifecycle()


func _test_battle_session_adapter_lifecycle_transitions() -> void:
	var adapter = BattleSessionAdapterScript.new()
	add_child(adapter)
	var config := _make_config()

	adapter.setup_from_start_config(config)
	_assert_true(adapter.get_lifecycle_state_name() == "IDLE", "battle adapter enters idle after setup")

	adapter.start_battle()
	_assert_true(adapter.get_lifecycle_state_name() == "RUNNING", "battle adapter enters running when context is created")

	for _tick in range(BattleSessionAdapterScript.DEFAULT_MATCH_DURATION_TICKS + 2):
		adapter.advance_authoritative_tick({})
		if adapter.get_lifecycle_state_name() == "FINISHING":
			break

	_assert_true(adapter.get_lifecycle_state_name() == "FINISHING", "battle adapter enters finishing after authoritative result")

	adapter.shutdown_battle()
	_assert_true(adapter.get_lifecycle_state_name() == "STOPPED", "battle adapter enters stopped after shutdown")
	_assert_true(adapter.is_shutdown_complete(), "battle adapter reports shutdown complete")
	adapter.free()


func _test_shutdown_resets_runtime_metrics_and_debug_state() -> void:
	var adapter = BattleSessionAdapterScript.new()
	add_child(adapter)
	adapter.setup_from_start_config(_make_config())
	adapter.cycle_latency_profile()
	adapter.cycle_loss_profile()
	adapter.toggle_remote_debug_inputs()
	adapter.arm_force_prediction_divergence()
	adapter.start_battle()
	adapter.advance_authoritative_tick({"move_x": 1})
	adapter.shutdown_battle()

	var metrics: Dictionary = adapter.build_runtime_metrics_snapshot()
	_assert_true(String(metrics.get("lifecycle_state_name", "")) == "STOPPED", "shutdown metrics report stopped lifecycle")
	_assert_true(not bool(metrics.get("battle_active", true)), "shutdown metrics report inactive battle")
	_assert_true(int(metrics.get("pending_server_messages", -1)) == 0, "shutdown clears pending server messages")
	_assert_true(int(metrics.get("correction_count", -1)) == 0, "shutdown clears correction count")
	_assert_true(String(metrics.get("last_correction", "")) == "", "shutdown clears last correction summary")
	_assert_true(int(metrics.get("last_resync_tick", 0)) == -1, "shutdown clears last resync tick")
	adapter.free()


func _test_app_root_dump_reports_battle_lifecycle() -> void:
	var runtime = AppRuntimeRootScript.new()
	add_child(runtime)
	runtime.initialize_runtime()
	runtime.battle_session_adapter.setup_from_start_config(_make_config())
	var dump_idle: Dictionary = runtime.debug_dump_runtime_structure()
	_assert_true(String(dump_idle.get("battle_lifecycle_state_name", "")) == "IDLE", "app root dump reports idle lifecycle")

	runtime.battle_session_adapter.start_battle()
	var dump_running: Dictionary = runtime.debug_dump_runtime_structure()
	_assert_true(String(dump_running.get("battle_lifecycle_state_name", "")) == "RUNNING", "app root dump reports running lifecycle")
	_assert_true(not bool(dump_running.get("battle_shutdown_complete", true)), "app root dump reports shutdown incomplete while running")

	runtime.battle_session_adapter.shutdown_battle()
	var dump_stopped: Dictionary = runtime.debug_dump_runtime_structure()
	_assert_true(String(dump_stopped.get("battle_lifecycle_state_name", "")) == "STOPPED", "app root dump reports stopped lifecycle")
	_assert_true(bool(dump_stopped.get("battle_shutdown_complete", false)), "app root dump reports shutdown complete after stop")

	runtime.queue_free()


func _make_config() -> BattleStartConfig:
	var config := BattleStartConfig.new()
	config.room_id = "lifecycle_contract_room"
	config.match_id = "lifecycle_contract_match"
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
