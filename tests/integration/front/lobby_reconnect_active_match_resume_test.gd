extends "res://tests/gut/base/qqt_integration_test.gd"

const BattleStartConfigScript = preload("res://gameplay/battle/config/battle_start_config.gd")
const FrontFlowControllerScript = preload("res://app/flow/front_flow_controller.gd")
const FrontSettingsStateScript = preload("res://app/front/profile/front_settings_state.gd")
const LobbyUseCaseScript = preload("res://app/front/lobby/lobby_use_case.gd")
const MatchResumeSnapshotScript = preload("res://network/session/runtime/match_resume_snapshot.gd")
const RoomUseCaseScript = preload("res://app/front/room/room_use_case.gd")


class MockAppRuntime:
	extends "res://tests/gut/base/qqt_integration_test.gd"

	var front_flow := FrontFlowControllerScript.new()
	var front_settings_state := FrontSettingsStateScript.new()
	var current_start_config: BattleStartConfig = null
	var current_resume_snapshot: MatchResumeSnapshot = null
	var current_loading_mode: String = "normal_start"

	func setup() -> void:
		if front_flow.get_parent() == null:
			add_child(front_flow)
		front_flow.enter_lobby()

	func apply_match_resume_payload(config: BattleStartConfig, resume_snapshot: MatchResumeSnapshot) -> void:
		current_start_config = config.duplicate_deep() if config != null else null
		current_resume_snapshot = resume_snapshot
		current_loading_mode = "resume_match"


func test_main() -> void:
	var ok := true
	ok = _test_lobby_reconnect_to_active_match_enters_resume_loading() and ok
	ok = _test_lobby_reconnect_without_member_session_fails() and ok
	ok = _test_lobby_reconnect_without_token_clears_stale_state() and ok


func _test_lobby_reconnect_to_active_match_enters_resume_loading() -> bool:
	var app_runtime := MockAppRuntime.new()
	add_child(app_runtime)
	app_runtime.setup()

	var use_case := RoomUseCaseScript.new()
	use_case.app_runtime = app_runtime
	var config := _build_resume_config()
	var snapshot := _build_resume_snapshot()

	use_case._on_gateway_match_resume_accepted(config, snapshot)

	var prefix := "lobby_reconnect_active_match_resume_test"
	var ok := true
	ok = qqt_check(app_runtime.current_loading_mode == "resume_match", "resume accepted should switch runtime loading mode", prefix) and ok
	ok = qqt_check(app_runtime.current_resume_snapshot == snapshot, "resume snapshot should be stored on runtime", prefix) and ok
	ok = qqt_check(app_runtime.current_start_config != null, "resume start config should be stored on runtime", prefix) and ok
	if app_runtime.current_start_config != null:
		ok = qqt_check(int(app_runtime.current_start_config.local_peer_id) == 9, "resume local peer should be reconnect transport peer", prefix) and ok
		ok = qqt_check(int(app_runtime.current_start_config.controlled_peer_id) == 3, "resume controlled peer should be original battle peer", prefix) and ok
	ok = qqt_check(
		app_runtime.front_flow.is_in_state(FrontFlowControllerScript.FlowState.MATCH_LOADING),
		"resume accepted from lobby should enter MATCH_LOADING",
		prefix
	) and ok

	use_case.dispose()
	app_runtime.free()
	return ok


func _test_lobby_reconnect_without_member_session_fails() -> bool:
	var settings := FrontSettingsStateScript.new()
	settings.reconnect_room_id = "LegacyMigration_room"
	settings.reconnect_host = "127.0.0.1"
	settings.reconnect_port = 9100
	settings.reconnect_room_kind = "private_room"
	settings.reconnect_token = "token_without_member"
	var use_case := LobbyUseCaseScript.new()
	use_case.configure(null, null, null, settings, null)

	var result := use_case.resume_recent_room()

	var prefix := "lobby_reconnect_active_match_resume_test"
	var ok := true
	ok = qqt_check(not bool(result.get("ok", true)), "resume without member id should fail", prefix) and ok
	ok = qqt_check(String(result.get("error_code", "")) == "RECONNECT_MEMBER_MISSING", "missing member id should return RECONNECT_MEMBER_MISSING", prefix) and ok
	ok = qqt_check(String(settings.reconnect_room_id) == "", "missing member id should clear stale reconnect room id", prefix) and ok
	ok = qqt_check(String(settings.reconnect_token) == "", "missing member id should clear stale reconnect token", prefix) and ok
	return ok


func _test_lobby_reconnect_without_token_clears_stale_state() -> bool:
	var settings := FrontSettingsStateScript.new()
	settings.reconnect_room_id = "LegacyMigration_room"
	settings.reconnect_host = "127.0.0.1"
	settings.reconnect_port = 9100
	settings.reconnect_room_kind = "private_room"
	settings.reconnect_member_id = "member_a"
	var use_case := LobbyUseCaseScript.new()
	use_case.configure(null, null, null, settings, null)

	var result := use_case.resume_recent_room()

	var prefix := "lobby_reconnect_active_match_resume_test"
	var ok := true
	ok = qqt_check(not bool(result.get("ok", true)), "resume without token should fail", prefix) and ok
	ok = qqt_check(String(result.get("error_code", "")) == "RECONNECT_TOKEN_MISSING", "missing token should return RECONNECT_TOKEN_MISSING", prefix) and ok
	ok = qqt_check(String(settings.reconnect_room_id) == "", "missing token should clear stale reconnect room id", prefix) and ok
	ok = qqt_check(String(settings.reconnect_member_id) == "", "missing token should clear stale reconnect member id", prefix) and ok
	return ok


func _build_resume_config() -> BattleStartConfig:
	var config := BattleStartConfigScript.new()
	config.room_id = "LegacyMigration_room"
	config.match_id = "LegacyMigration_match"
	config.map_id = "map_001"
	config.map_content_hash = "hash"
	config.mode_id = "mode_001"
	config.rule_set_id = "rule_001"
	config.player_slots = [
		{"peer_id": 2, "slot_index": 0, "player_name": "Host", "character_id": "hero_default"},
		{"peer_id": 3, "slot_index": 1, "player_name": "Client", "character_id": "hero_default"},
	]
	config.spawn_assignments = [
		{"peer_id": 2, "slot_index": 0, "cell": Vector2i(1, 1)},
		{"peer_id": 3, "slot_index": 1, "cell": Vector2i(3, 3)},
	]
	config.session_mode = "network_client"
	config.topology = "dedicated_server"
	config.local_peer_id = 9
	config.controlled_peer_id = 3
	config.owner_peer_id = 2
	config.server_match_revision = 7
	return config


func _build_resume_snapshot() -> MatchResumeSnapshot:
	var snapshot := MatchResumeSnapshotScript.new()
	snapshot.room_id = "LegacyMigration_room"
	snapshot.match_id = "LegacyMigration_match"
	snapshot.member_id = "member_2"
	snapshot.transport_peer_id = 9
	snapshot.controlled_peer_id = 3
	snapshot.resume_tick = 120
	snapshot.checkpoint_message = {
		"message_type": "CHECKPOINT",
		"tick": 120,
		"players": [],
		"bubbles": [],
		"items": [],
		"walls": [],
		"mode_state": {},
		"rng_state": 1,
		"checksum": 2,
	}
	return snapshot

