extends "res://tests/gut/base/qqt_integration_test.gd"

const BattleStartConfigScript = preload("res://gameplay/battle/config/battle_start_config.gd")
const RoomServerStateScript = preload("res://network/session/runtime/room_server_state.gd")
const ServerMatchResumeCoordinatorScript = preload("res://network/session/runtime/server_match_resume_coordinator.gd")
const ServerMatchServiceScript = preload("res://network/session/runtime/server_match_service.gd")
const ResumeTokenUtilsScript = preload("res://network/session/runtime/resume_token_utils.gd")


class MockMatchService:
	extends ServerMatchService
	var active: bool = true
	var config: BattleStartConfig = null
	var checkpoint: Dictionary = {"tick": 100}

	func is_match_active() -> bool:
		return active

	func get_current_config() -> BattleStartConfig:
		return config.duplicate_deep() if config != null else null

	func build_resume_checkpoint_message() -> Dictionary:
		return checkpoint.duplicate(true)


func test_main() -> void:
	var fixture := _create_fixture()
	var state: RoomServerState = fixture["state"]
	var service: MockMatchService = fixture["service"]
	var coordinator: ServerMatchResumeCoordinator = fixture["coordinator"]
	var binding = state.get_member_binding_by_transport_peer(2)
	var member_id := String(binding.member_id)
	var token := String(binding.reconnect_token)
	var prefix := "battle_resume_window_e2e_test"
	var ok := true

	ok = qqt_check(not token.is_empty(), "resume token hash source should exist for member", prefix) and ok

	coordinator.on_member_disconnected(member_id)
	var in_window := coordinator.try_resume(member_id, token, 9, "match_456")
	ok = qqt_check(bool(in_window.get("ok", false)), "resume in active window should succeed", prefix) and ok

	state.mark_member_disconnected_by_transport_peer(9, 1, "match_456")
	var out_window := coordinator.try_resume(member_id, token, 11, "match_456")
	ok = qqt_check(not bool(out_window.get("ok", true)) and String(out_window.get("error", "")) == "RESUME_WINDOW_EXPIRED", "resume out of window should fail", prefix) and ok

	service.active = false
	state.mark_member_disconnected_by_transport_peer(9, Time.get_ticks_msec() + 30000, "match_456")
	var after_logout := coordinator.try_resume(member_id, token, 12, "match_456")
	ok = qqt_check(not bool(after_logout.get("ok", true)) and String(after_logout.get("error", "")) == "MATCH_NOT_ACTIVE", "resume should fail after logout/inactive", prefix) and ok

	var token_hash := ResumeTokenUtilsScript.hash_resume_token(token)
	ok = qqt_check(not token_hash.is_empty(), "resume token hash generation should be valid", prefix) and ok



func _create_fixture() -> Dictionary:
	var state := RoomServerStateScript.new()
	state.ensure_room("room_123", 2, "private_room", "Resume Room")
	state.upsert_member(2, "Player2", "hero_default")
	state.upsert_member(3, "Player3", "hero_default")
	state.freeze_match_peer_bindings("match_456")
	state.match_active = true

	var service := MockMatchService.new()
	service.config = _build_config("match_456")
	add_child(service)

	var coordinator := ServerMatchResumeCoordinatorScript.new()
	coordinator.configure(state, service)
	add_child(coordinator)
	return {
		"state": state,
		"service": service,
		"coordinator": coordinator,
	}


func _build_config(match_id: String) -> BattleStartConfig:
	var config := BattleStartConfigScript.new()
	config.room_id = "room_123"
	config.match_id = match_id
	config.map_id = "map_001"
	config.mode_id = "mode_001"
	config.rule_set_id = "rule_001"
	config.player_slots = [
		{"peer_id": 2, "slot_index": 0, "player_name": "Player2", "character_id": "hero_default"},
		{"peer_id": 3, "slot_index": 1, "player_name": "Player3", "character_id": "hero_default"},
	]
	config.topology = "dedicated_server"
	config.owner_peer_id = 2
	return config

