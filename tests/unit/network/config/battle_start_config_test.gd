extends Node

const TestAssert = preload("res://tests/helpers/test_assert.gd")
const BattleStartConfigScript = preload("res://gameplay/battle/config/battle_start_config.gd")
const MatchStartCoordinatorScript = preload("res://network/session/match_start_coordinator.gd")
const MapLoaderScript = preload("res://content/maps/runtime/map_loader.gd")
const CharacterCatalogScript = preload("res://content/characters/catalog/character_catalog.gd")
const RuleCatalogScript = preload("res://content/rules/rule_catalog.gd")


func _ready() -> void:
	var ok := true
	ok = _test_valid_config_passes_validation() and ok
	ok = _test_build_start_config_reads_map_metadata() and ok
	ok = _test_protocol_mismatch_fails_validation() and ok
	ok = _test_map_hash_mismatch_fails_validation() and ok
	ok = _test_duplicate_slot_fails_validation() and ok
	ok = _test_invalid_spawn_assignment_fails_validation() and ok
	if ok:
		print("battle_start_config_test: PASS")


func _test_valid_config_passes_validation() -> bool:
	var coordinator := MatchStartCoordinatorScript.new()
	var config := _make_valid_config()
	var validation := coordinator.validate_start_config(config)
	var prefix := "battle_start_config_test"
	var ok := true
	ok = TestAssert.is_true(bool(validation.get("ok", false)), "valid config should pass validate_start_config", prefix) and ok
	ok = TestAssert.is_true(config.to_pretty_json().contains("protocol_version"), "config should serialize to json with new fields", prefix) and ok
	ok = TestAssert.is_true(config.to_log_string().contains("valid=True") or config.to_log_string().contains("valid=true"), "config log string should report validation status", prefix) and ok
	coordinator.free()
	return ok


func _test_build_start_config_reads_map_metadata() -> bool:
	var coordinator := MatchStartCoordinatorScript.new()
	var snapshot := _make_room_snapshot()
	var config := coordinator.build_start_config(snapshot)
	var metadata := MapLoaderScript.load_map_metadata("default_map")
	var prefix := "battle_start_config_test"
	var ok := true
	ok = TestAssert.is_true(not config.match_id.is_empty(), "build_start_config should create a match id", prefix) and ok
	ok = TestAssert.is_true(int(config.map_version) == int(metadata.get("version", -1)), "build_start_config should copy map_version from metadata", prefix) and ok
	ok = TestAssert.is_true(String(config.map_content_hash) == String(metadata.get("content_hash", "")), "build_start_config should copy map_content_hash from metadata", prefix) and ok
	ok = TestAssert.is_true(String(config.item_spawn_profile_id) == String(metadata.get("item_spawn_profile_id", "")), "build_start_config should copy item spawn profile", prefix) and ok
	coordinator.free()
	return ok


func _test_protocol_mismatch_fails_validation() -> bool:
	var coordinator := MatchStartCoordinatorScript.new()
	var config := _make_valid_config()
	config.protocol_version += 1
	var validation := coordinator.validate_start_config(config)
	var prefix := "battle_start_config_test"
	var ok := true
	ok = TestAssert.is_true(not bool(validation.get("ok", true)), "protocol mismatch should fail validation", prefix) and ok
	ok = TestAssert.is_true(_errors_contain(validation, "protocol_version mismatch"), "protocol mismatch should produce a clear error", prefix) and ok
	coordinator.free()
	return ok


func _test_map_hash_mismatch_fails_validation() -> bool:
	var coordinator := MatchStartCoordinatorScript.new()
	var config := _make_valid_config()
	config.map_content_hash = "broken_hash"
	var validation := coordinator.validate_start_config(config)
	var prefix := "battle_start_config_test"
	var ok := true
	ok = TestAssert.is_true(not bool(validation.get("ok", true)), "map hash mismatch should fail validation", prefix) and ok
	ok = TestAssert.is_true(_errors_contain(validation, "map_content_hash mismatch"), "map hash mismatch should produce a clear error", prefix) and ok
	coordinator.free()
	return ok


func _test_duplicate_slot_fails_validation() -> bool:
	var coordinator := MatchStartCoordinatorScript.new()
	var config := _make_valid_config()
	config.player_slots[1]["slot_index"] = 0
	config.players = config.player_slots.duplicate(true)
	var validation := coordinator.validate_start_config(config)
	var prefix := "battle_start_config_test"
	var ok := true
	ok = TestAssert.is_true(not bool(validation.get("ok", true)), "duplicate slot_index should fail validation", prefix) and ok
	ok = TestAssert.is_true(_errors_contain(validation, "duplicate slot_index"), "duplicate slot_index should be reported", prefix) and ok
	coordinator.free()
	return ok


func _test_invalid_spawn_assignment_fails_validation() -> bool:
	var coordinator := MatchStartCoordinatorScript.new()
	var config := _make_valid_config()
	config.spawn_assignments = [{
		"peer_id": 999,
		"slot_index": 0,
		"spawn_index": 0,
		"spawn_cell_x": 1,
		"spawn_cell_y": 1,
	}]
	var validation := coordinator.validate_start_config(config)
	var prefix := "battle_start_config_test"
	var ok := true
	ok = TestAssert.is_true(not bool(validation.get("ok", true)), "invalid spawn assignment should fail validation", prefix) and ok
	ok = TestAssert.is_true(_errors_contain(validation, "unknown peer_id"), "invalid spawn assignment should mention unknown peer", prefix) and ok
	coordinator.free()
	return ok


func _make_valid_config() -> BattleStartConfig:
	var metadata := MapLoaderScript.load_map_metadata("default_map")
	var rule_metadata := RuleCatalogScript.get_rule_metadata("classic")
	var host_character_metadata := CharacterCatalogScript.get_character_metadata("hero_default")
	var client_character_metadata := CharacterCatalogScript.get_character_metadata("hero_runner")
	var config := BattleStartConfigScript.new()
	config.protocol_version = BattleStartConfigScript.DEFAULT_PROTOCOL_VERSION
	config.gameplay_rule_version = int(rule_metadata.get("version", BattleStartConfigScript.DEFAULT_GAMEPLAY_RULE_VERSION))
	config.build_mode = BattleStartConfigScript.BUILD_MODE_CANDIDATE
	config.room_id = "config_test_room"
	config.match_id = "config_test_match"
	config.map_id = "default_map"
	config.map_version = int(metadata.get("version", 1))
	config.map_content_hash = String(metadata.get("content_hash", "hash"))
	config.rule_set_id = "classic"
	config.battle_seed = 12345
	config.start_tick = 0
	config.match_duration_ticks = 60
	config.item_spawn_profile_id = String(metadata.get("item_spawn_profile_id", "default_items"))
	config.session_mode = "singleplayer_local"
	config.topology = "listen"
	config.local_peer_id = 1
	config.controlled_peer_id = 1
	config.owner_peer_id = 1
	config.player_slots = [
		{
			"peer_id": 1,
			"player_name": "Host",
			"slot_index": 0,
			"spawn_slot": 0,
			"character_id": "hero_default",
		},
		{
			"peer_id": 2,
			"player_name": "Client",
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
	var spawn_points: Array = metadata.get("spawn_points", [])
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


func _make_room_snapshot() -> RoomSnapshot:
	var snapshot := RoomSnapshot.new()
	snapshot.room_id = "config_test_room"
	snapshot.owner_peer_id = 1
	snapshot.selected_map_id = "default_map"
	snapshot.rule_set_id = "classic"
	snapshot.all_ready = true
	snapshot.max_players = 2

	var host := RoomMemberState.new()
	host.peer_id = 1
	host.player_name = "Host"
	host.ready = true
	host.slot_index = 0
	host.character_id = "hero_default"
	snapshot.members.append(host)

	var client := RoomMemberState.new()
	client.peer_id = 2
	client.player_name = "Client"
	client.ready = true
	client.slot_index = 1
	client.character_id = "hero_runner"
	snapshot.members.append(client)
	return snapshot


func _errors_contain(validation: Dictionary, needle: String) -> bool:
	for entry in validation.get("errors", []):
		if String(entry).contains(needle):
			return true
	return false
