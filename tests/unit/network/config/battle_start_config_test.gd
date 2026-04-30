extends "res://tests/gut/base/qqt_unit_test.gd"

const BattleStartConfigScript = preload("res://gameplay/battle/config/battle_start_config.gd")
const MatchStartCoordinatorScript = preload("res://network/session/match_start_coordinator.gd")
const MapLoaderScript = preload("res://content/maps/runtime/map_loader.gd")
const MapCatalogScript = preload("res://content/maps/catalog/map_catalog.gd")
const MapSelectionCatalogScript = preload("res://content/maps/catalog/map_selection_catalog.gd")
const CharacterCatalogScript = preload("res://content/characters/catalog/character_catalog.gd")
const CharacterSkinCatalogScript = preload("res://content/character_skins/catalog/character_skin_catalog.gd")
const BubbleSkinCatalogScript = preload("res://content/bubble_skins/catalog/bubble_skin_catalog.gd")
const RuleSetCatalogScript = preload("res://content/rulesets/catalog/rule_set_catalog.gd")


func test_main() -> void:
	var ok := true
	ok = _test_valid_config_passes_validation() and ok
	ok = _test_build_start_config_reads_map_metadata() and ok
	ok = _test_build_start_config_prefers_authoritative_match_id() and ok
	ok = _test_build_start_config_carries_player_visual_loadout_fields() and ok
	ok = _test_protocol_mismatch_fails_validation() and ok
	ok = _test_map_hash_mismatch_fails_validation() and ok
	ok = _test_duplicate_slot_fails_validation() and ok
	ok = _test_invalid_team_id_fails_validation() and ok
	ok = _test_invalid_spawn_assignment_fails_validation() and ok


func _test_valid_config_passes_validation() -> bool:
	var coordinator := MatchStartCoordinatorScript.new()
	var config := _make_valid_config()
	var validation := coordinator.validate_start_config(config)
	var prefix := "battle_start_config_test"
	var ok := true
	ok = qqt_check(
		bool(validation.get("ok", false)),
		"valid config should pass validate_start_config errors=%s" % str(validation.get("errors", [])),
		prefix
	) and ok
	ok = qqt_check(config.to_pretty_json().contains("protocol_version"), "config should serialize to json with new fields", prefix) and ok
	ok = qqt_check(config.to_log_string().contains("valid=True") or config.to_log_string().contains("valid=true"), "config log string should report validation status", prefix) and ok
	coordinator.free()
	return ok


func _test_build_start_config_reads_map_metadata() -> bool:
	var coordinator := MatchStartCoordinatorScript.new()
	var snapshot := _make_room_snapshot()
	var config := coordinator.build_start_config(snapshot)
	var default_map_id := MapCatalogScript.get_default_map_id()
	var metadata := MapLoaderScript.load_map_metadata(default_map_id)
	var prefix := "battle_start_config_test"
	var ok := true
	ok = qqt_check(not config.match_id.is_empty(), "build_start_config should create a match id", prefix) and ok
	ok = qqt_check(int(config.map_version) == int(metadata.get("version", -1)), "build_start_config should copy map_version from metadata", prefix) and ok
	ok = qqt_check(String(config.map_content_hash) == String(metadata.get("content_hash", "")), "build_start_config should copy map_content_hash from metadata", prefix) and ok
	ok = qqt_check(String(config.item_spawn_profile_id) == String(metadata.get("item_spawn_profile_id", "")), "build_start_config should copy item spawn profile", prefix) and ok
	coordinator.free()
	return ok


func _test_build_start_config_prefers_authoritative_match_id() -> bool:
	var coordinator := MatchStartCoordinatorScript.new()
	var snapshot := _make_room_snapshot()
	snapshot.current_match_id = "match_authoritative_42"
	var config := coordinator.build_start_config(snapshot)
	var prefix := "battle_start_config_test"
	var ok := true
	ok = qqt_check(
		config.match_id == "match_authoritative_42",
		"build_start_config should preserve snapshot.current_match_id in assignment flow",
		prefix
	) and ok
	coordinator.free()
	return ok


func _test_build_start_config_carries_player_visual_loadout_fields() -> bool:
	var coordinator := MatchStartCoordinatorScript.new()
	var snapshot := _make_room_snapshot()
	var host := snapshot.members[0] as RoomMemberState
	host.character_id = "char_16001" if CharacterCatalogScript.has_character("char_16001") else CharacterCatalogScript.get_default_character_id()
	host.character_skin_id = CharacterSkinCatalogScript.get_default_skin_id()
	host.bubble_style_id = "bubble_round"
	host.bubble_skin_id = BubbleSkinCatalogScript.get_default_skin_id()
	host.team_id = 8
	var config := coordinator.build_start_config(snapshot)
	var host_slot := _find_entry_for_peer(config.player_slots, host.peer_id)
	var host_character_loadout := _find_entry_for_peer(config.character_loadouts, host.peer_id)
	var host_bubble_loadout := _find_entry_for_peer(config.player_bubble_loadouts, host.peer_id)
	var prefix := "battle_start_config_test"
	var ok := true
	ok = qqt_check(int(host_slot.get("team_id", 0)) == 8, "player_slots should carry selected team_id", prefix) and ok
	ok = qqt_check(String(host_slot.get("character_id", "")) == host.character_id, "player_slots should carry selected character_id", prefix) and ok
	ok = qqt_check(String(host_slot.get("character_skin_id", "")) == host.character_skin_id, "player_slots should carry selected character_skin_id", prefix) and ok
	ok = qqt_check(String(host_slot.get("bubble_style_id", "")) == host.bubble_style_id, "player_slots should carry selected bubble_style_id", prefix) and ok
	ok = qqt_check(String(host_slot.get("bubble_skin_id", "")) == host.bubble_skin_id, "player_slots should carry selected bubble_skin_id", prefix) and ok
	ok = qqt_check(int(host_character_loadout.get("team_id", 0)) == 8, "character_loadouts should carry team_id", prefix) and ok
	ok = qqt_check(String(host_character_loadout.get("character_skin_id", "")) == host.character_skin_id, "character_loadouts should carry character_skin_id", prefix) and ok
	ok = qqt_check(not String(host_character_loadout.get("animation_set_id", "")).is_empty(), "character_loadouts should carry resolved animation_set_id", prefix) and ok
	ok = qqt_check(String(host_bubble_loadout.get("bubble_style_id", "")) == host.bubble_style_id, "player_bubble_loadouts should carry bubble_style_id", prefix) and ok
	ok = qqt_check(String(host_bubble_loadout.get("bubble_skin_id", "")) == host.bubble_skin_id, "player_bubble_loadouts should carry bubble_skin_id", prefix) and ok
	coordinator.free()
	return ok


func _test_protocol_mismatch_fails_validation() -> bool:
	var coordinator := MatchStartCoordinatorScript.new()
	var config := _make_valid_config()
	config.protocol_version += 1
	var validation := coordinator.validate_start_config(config)
	var prefix := "battle_start_config_test"
	var ok := true
	ok = qqt_check(not bool(validation.get("ok", true)), "protocol mismatch should fail validation", prefix) and ok
	ok = qqt_check(_errors_contain(validation, "protocol_version mismatch"), "protocol mismatch should produce a clear error", prefix) and ok
	coordinator.free()
	return ok


func _test_map_hash_mismatch_fails_validation() -> bool:
	var coordinator := MatchStartCoordinatorScript.new()
	var config := _make_valid_config()
	config.map_content_hash = "broken_hash"
	var validation := coordinator.validate_start_config(config)
	var prefix := "battle_start_config_test"
	var ok := true
	ok = qqt_check(not bool(validation.get("ok", true)), "map hash mismatch should fail validation", prefix) and ok
	ok = qqt_check(_errors_contain(validation, "map_content_hash mismatch"), "map hash mismatch should produce a clear error", prefix) and ok
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
	ok = qqt_check(not bool(validation.get("ok", true)), "duplicate slot_index should fail validation", prefix) and ok
	ok = qqt_check(_errors_contain(validation, "duplicate slot_index"), "duplicate slot_index should be reported", prefix) and ok
	coordinator.free()
	return ok


func _test_invalid_team_id_fails_validation() -> bool:
	var coordinator := MatchStartCoordinatorScript.new()
	var config := _make_valid_config()
	config.player_slots[0]["team_id"] = 0
	config.players = config.player_slots.duplicate(true)
	var validation := coordinator.validate_start_config(config)
	var prefix := "battle_start_config_test"
	var ok := true
	ok = qqt_check(not bool(validation.get("ok", true)), "invalid team_id should fail validation", prefix) and ok
	ok = qqt_check(_errors_contain(validation, "invalid team_id"), "invalid team_id should be reported", prefix) and ok
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
	ok = qqt_check(not bool(validation.get("ok", true)), "invalid spawn assignment should fail validation", prefix) and ok
	ok = qqt_check(_errors_contain(validation, "unknown peer_id"), "invalid spawn assignment should mention unknown peer", prefix) and ok
	coordinator.free()
	return ok


func _make_valid_config() -> BattleStartConfig:
	var default_map_id := MapCatalogScript.get_default_map_id()
	var map_metadata := MapLoaderScript.load_map_metadata(default_map_id)
	var binding := MapSelectionCatalogScript.get_map_binding(default_map_id)
	var resolved_mode_id := String(binding.get("bound_mode_id", ""))
	var resolved_rule_set_id := String(binding.get("bound_rule_set_id", ""))
	if resolved_mode_id.is_empty():
		resolved_mode_id = "mode_classic"
	if resolved_rule_set_id.is_empty():
		resolved_rule_set_id = "ruleset_classic"
	var rule_metadata := RuleSetCatalogScript.get_rule_metadata(resolved_rule_set_id)
	var default_character_id := CharacterCatalogScript.get_default_character_id()
	var host_character_metadata := CharacterCatalogScript.get_character_metadata(default_character_id)
	var client_character_metadata := CharacterCatalogScript.get_character_metadata(default_character_id)

	var config := BattleStartConfigScript.new()
	config.protocol_version = BattleStartConfigScript.DEFAULT_PROTOCOL_VERSION
	config.gameplay_rule_version = int(rule_metadata.get("version", BattleStartConfigScript.DEFAULT_GAMEPLAY_RULE_VERSION))
	config.build_mode = BattleStartConfigScript.BUILD_MODE_CANDIDATE
	config.room_id = "config_test_room"
	config.match_id = "config_test_match"
	config.map_id = default_map_id
	config.map_version = int(map_metadata.get("version", BattleStartConfigScript.DEFAULT_MAP_VERSION))
	config.map_content_hash = String(map_metadata.get("content_hash", ""))
	config.mode_id = resolved_mode_id
	config.rule_set_id = resolved_rule_set_id
	config.battle_seed = 12345
	config.start_tick = 0
	config.match_duration_ticks = 60
	config.item_spawn_profile_id = String(map_metadata.get("item_spawn_profile_id", BattleStartConfigScript.DEFAULT_ITEM_SPAWN_PROFILE_ID))
	config.session_mode = "singleplayer_local"
	config.topology = "local"
	config.local_peer_id = 1
	config.controlled_peer_id = 1
	config.owner_peer_id = 1
	config.player_slots = [
		{
			"peer_id": 1,
			"player_name": "Host",
			"slot_index": 0,
			"spawn_slot": 0,
			"character_id": default_character_id,
			"team_id": 1,
		},
		{
			"peer_id": 2,
			"player_name": "Client",
			"slot_index": 1,
			"spawn_slot": 1,
			"character_id": default_character_id,
			"team_id": 2,
		},
	]
	config.players = config.player_slots.duplicate(true)
	config.character_loadouts = [
		{
			"peer_id": 1,
			"character_id": default_character_id,
			"content_hash": String(host_character_metadata.get("content_hash", default_character_id)),
		},
		{
			"peer_id": 2,
			"character_id": default_character_id,
			"content_hash": String(client_character_metadata.get("content_hash", default_character_id)),
		},
	]
	var spawn_points: Array = map_metadata.get("spawn_points", [])
	config.spawn_assignments = [
		{
			"peer_id": 1,
			"slot_index": 0,
			"spawn_index": 0,
			"spawn_cell_x": _spawn_cell_component(spawn_points, 0, true),
			"spawn_cell_y": _spawn_cell_component(spawn_points, 0, false),
		},
		{
			"peer_id": 2,
			"slot_index": 1,
			"spawn_index": 1,
			"spawn_cell_x": _spawn_cell_component(spawn_points, 1, true),
			"spawn_cell_y": _spawn_cell_component(spawn_points, 1, false),
		},
	]
	config.sort_players()
	return config


func _spawn_cell_component(spawn_points: Array, index: int, axis_x: bool) -> int:
	if index < 0 or index >= spawn_points.size():
		return index + 1
	var point = spawn_points[index]
	if point is Vector2i:
		return point.x if axis_x else point.y
	if point is Dictionary:
		var key := "x" if axis_x else "y"
		return int(point.get(key, index + 1))
	return index + 1


func _make_room_snapshot() -> RoomSnapshot:
	var default_map_id := MapCatalogScript.get_default_map_id()
	var default_character_id := CharacterCatalogScript.get_default_character_id()
	var snapshot := RoomSnapshot.new()
	snapshot.room_id = "config_test_room"
	snapshot.topology = "local"
	snapshot.owner_peer_id = 1
	snapshot.selected_map_id = default_map_id
	snapshot.rule_set_id = "ruleset_classic"
	snapshot.mode_id = "mode_classic"
	snapshot.selected_match_mode_ids = ["mode_classic"]
	snapshot.all_ready = true
	snapshot.max_players = 2

	var host := RoomMemberState.new()
	host.peer_id = 1
	host.player_name = "Host"
	host.ready = true
	host.slot_index = 0
	host.character_id = default_character_id
	host.team_id = 1
	snapshot.members.append(host)

	var client := RoomMemberState.new()
	client.peer_id = 2
	client.player_name = "Client"
	client.ready = true
	client.slot_index = 1
	client.character_id = default_character_id
	client.team_id = 2
	snapshot.members.append(client)
	return snapshot


func _errors_contain(validation: Dictionary, needle: String) -> bool:
	for entry in validation.get("errors", []):
		if String(entry).contains(needle):
			return true
	return false


func _find_entry_for_peer(entries: Array[Dictionary], peer_id: int) -> Dictionary:
	for entry in entries:
		if int(entry.get("peer_id", -1)) == peer_id:
			return entry
	return {}
