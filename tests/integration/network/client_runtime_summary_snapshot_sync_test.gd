extends Node

const TestAssertScript = preload("res://tests/helpers/test_assert.gd")
const BattleStartConfigScript = preload("res://gameplay/battle/config/battle_start_config.gd")
const ClientRuntimeScript = preload("res://network/session/runtime/client_runtime.gd")
const TransportMessageTypesScript = preload("res://network/transport/transport_message_types.gd")
const TileConstants = preload("res://gameplay/simulation/state/tile_constants.gd")
const MapLoaderScript = preload("res://content/maps/runtime/map_loader.gd")
const MapCatalogScript = preload("res://content/maps/catalog/map_catalog.gd")
const ModeCatalogScript = preload("res://content/modes/catalog/mode_catalog.gd")
const RuleSetCatalogScript = preload("res://content/rulesets/catalog/rule_set_catalog.gd")
const CharacterCatalogScript = preload("res://content/characters/catalog/character_catalog.gd")


func _ready() -> void:
	var ok := _test_state_summary_only_refreshes_sideband_entities_in_snapshot_buffer()
	ok = _test_dedicated_server_place_input_does_not_spawn_predicted_bubble_entities() and ok
	ok = _test_dedicated_server_disables_authority_only_history_compare() and ok
	ok = _test_dedicated_server_skips_non_aligned_sideband_restore() and ok
	ok = _test_dedicated_server_accepts_monotonic_sideband_restore() and ok
	ok = _test_dedicated_server_applies_authoritative_walls_sideband_to_current_world() and ok
	if ok:
		print("client_runtime_summary_snapshot_sync_test: PASS")


func _test_state_summary_only_refreshes_sideband_entities_in_snapshot_buffer() -> bool:
	var client := ClientRuntimeScript.new()
	add_child(client)

	var config := _make_config()
	client.configure(2)
	var prefix := "client_runtime_summary_snapshot_sync_test"
	var ok := true
	ok = TestAssertScript.is_true(client.start_match(config), "client runtime should start for summary sideband sync test", prefix) and ok
	if not ok:
		_cleanup_nodes([client])
		return false

	var world := client.prediction_controller.predicted_sim_world
	world.state.match_state.tick = 1
	if world.tick_runner != null:
		world.tick_runner.set_tick(1)

	var stale_snapshot := client.snapshot_service.build_light_snapshot(world, 1)
	client.prediction_controller.snapshot_buffer.put(stale_snapshot)
	var local_entry := _find_player_entry(stale_snapshot.players, 1)
	var authoritative_players := stale_snapshot.players.duplicate(true)
	for index in range(authoritative_players.size()):
		if int(authoritative_players[index].get("player_slot", -1)) != 1:
			continue
		authoritative_players[index]["bomb_available"] = 0
		break

	var summary_message := {
		"message_type": TransportMessageTypesScript.STATE_SUMMARY,
		"msg_type": TransportMessageTypesScript.STATE_SUMMARY,
		"tick": 1,
		"checksum": 111,
		"player_summary": authoritative_players,
		"bubbles": [{
			"entity_id": 1,
			"generation": 1,
			"alive": true,
			"owner_player_id": int(local_entry.get("entity_id", -1)),
			"bubble_type": 0,
			"cell_x": int(local_entry.get("cell_x", 0)),
			"cell_y": int(local_entry.get("cell_y", 0)),
			"spawn_tick": 1,
			"explode_tick": 61,
			"bubble_range": 1,
			"moving_state": 0,
			"move_dir_x": 0,
			"move_dir_y": 0,
			"pierce": false,
			"chain_triggered": false,
			"remote_group_id": 0,
			"ignore_player_ids": []
		}],
		"items": []
	}
	client.ingest_network_message(summary_message)

	var buffered_snapshot := client.prediction_controller.snapshot_buffer.get_snapshot(1)
	ok = TestAssertScript.is_true(buffered_snapshot != null, "summary should keep stale tick-1 snapshot in buffer", prefix) and ok
	ok = TestAssertScript.is_true(
		buffered_snapshot != null and buffered_snapshot.bubbles.size() == stale_snapshot.bubbles.size(),
		"summary should not mutate buffered bubbles for tick-1",
		prefix
	) and ok
	ok = TestAssertScript.is_true(
		int(_find_player_entry(buffered_snapshot.players, 1).get("bomb_available", -1)) == int(local_entry.get("bomb_available", -1)),
		"summary should not mutate buffered local player fields for tick-1",
		prefix
	) and ok

	var rollback_before := client.prediction_controller.rollback_controller.rollback_count
	var resync_before := client.prediction_controller.rollback_controller.force_resync_count
	client.ingest_network_message({
		"message_type": TransportMessageTypesScript.CHECKPOINT,
		"msg_type": TransportMessageTypesScript.CHECKPOINT,
		"tick": 1,
		"players": authoritative_players,
		"player_summary": authoritative_players,
		"bubbles": summary_message["bubbles"],
		"items": summary_message["items"],
		"checksum": int(summary_message.get("checksum", 0))
	})
	ok = TestAssertScript.is_true(
		client.prediction_controller.rollback_controller.rollback_count > rollback_before
			or client.prediction_controller.rollback_controller.force_resync_count > resync_before,
		"checkpoint should still trigger divergence handling when local player fields differ after summary leaves history untouched",
		prefix
	) and ok

	_cleanup_nodes([client])
	return ok


func _find_player_entry(players: Array, slot: int) -> Dictionary:
	for entry in players:
		if int(entry.get("player_slot", -1)) == slot:
			return entry
	return {}


func _test_dedicated_server_place_input_does_not_spawn_predicted_bubble_entities() -> bool:
	var client := ClientRuntimeScript.new()
	add_child(client)

	var config := _make_config()
	config.topology = "dedicated_server"
	client.configure(2)
	var prefix := "client_runtime_summary_snapshot_sync_test"
	var ok := true
	ok = TestAssertScript.is_true(client.start_match(config), "client runtime should start for dedicated place suppression test", prefix) and ok
	if not ok:
		_cleanup_nodes([client])
		return false

	var world := client.prediction_controller.predicted_sim_world
	var bubbles_before := world.state.bubbles.active_ids.size()
	var input_message := client.build_local_input_message({
		"move_x": 0,
		"move_y": 0,
		"action_place": true,
	})
	var bubbles_after := world.state.bubbles.active_ids.size()
	var input_frame : Dictionary = input_message.get("frame", {})

	ok = TestAssertScript.is_true(not input_message.is_empty(), "client should emit an input message for place prediction", prefix) and ok
	ok = TestAssertScript.is_true(
		bool(input_frame.get("action_place", false)),
		"dedicated server client should still send authoritative place intent",
		prefix
	) and ok
	ok = TestAssertScript.is_true(
		bubbles_after == bubbles_before,
		"dedicated server client should not spawn predicted bubble entities locally",
		prefix
	) and ok

	_cleanup_nodes([client])
	return ok


func _test_dedicated_server_disables_authority_only_history_compare() -> bool:
	var client := ClientRuntimeScript.new()
	add_child(client)

	var config := _make_config()
	config.topology = "dedicated_server"
	client.configure(2)
	var prefix := "client_runtime_summary_snapshot_sync_test"
	var ok := true
	ok = TestAssertScript.is_true(client.start_match(config), "client runtime should start for dedicated rollback compare test", prefix) and ok
	if not ok:
		_cleanup_nodes([client])
		return false

	ok = TestAssertScript.is_true(
		not client.prediction_controller.rollback_controller.compare_bubbles,
		"dedicated server should disable historical bubble comparison in rollback",
		prefix
	) and ok
	ok = TestAssertScript.is_true(
		not client.prediction_controller.rollback_controller.compare_items,
		"dedicated server should disable historical item comparison in rollback",
		prefix
	) and ok

	_cleanup_nodes([client])
	return ok


func _test_dedicated_server_skips_non_aligned_sideband_restore() -> bool:
	var client := ClientRuntimeScript.new()
	add_child(client)

	var config := _make_config()
	config.topology = "dedicated_server"
	client.configure(2)
	var prefix := "client_runtime_summary_snapshot_sync_test"
	var ok := true
	ok = TestAssertScript.is_true(client.start_match(config), "client runtime should start for dedicated sideband alignment test", prefix) and ok
	if not ok:
		_cleanup_nodes([client])
		return false

	var world := client.prediction_controller.predicted_sim_world
	world.state.match_state.tick = 3
	if world.tick_runner != null:
		world.tick_runner.set_tick(3)

	client.ingest_network_message({
		"message_type": TransportMessageTypesScript.STATE_SUMMARY,
		"msg_type": TransportMessageTypesScript.STATE_SUMMARY,
		"tick": 3,
		"player_summary": [],
		"bubbles": [{
			"entity_id": 98,
			"generation": 1,
			"alive": true,
			"owner_player_id": 1,
			"bubble_type": 0,
			"cell_x": 3,
			"cell_y": 3,
			"spawn_tick": 3,
			"explode_tick": 63,
			"bubble_range": 1,
			"moving_state": 0,
			"move_dir_x": 0,
			"move_dir_y": 0,
			"pierce": false,
			"chain_triggered": false,
			"remote_group_id": 0,
			"ignore_player_ids": []
		}],
		"items": []
	})

	client.ingest_network_message({
		"message_type": TransportMessageTypesScript.STATE_SUMMARY,
		"msg_type": TransportMessageTypesScript.STATE_SUMMARY,
		"tick": 1,
		"player_summary": [],
		"bubbles": [{
			"entity_id": 99,
			"generation": 1,
			"alive": true,
			"owner_player_id": 1,
			"bubble_type": 0,
			"cell_x": 1,
			"cell_y": 1,
			"spawn_tick": 1,
			"explode_tick": 61,
			"bubble_range": 1,
			"moving_state": 0,
			"move_dir_x": 0,
			"move_dir_y": 0,
			"pierce": false,
			"chain_triggered": false,
			"remote_group_id": 0,
			"ignore_player_ids": []
		}],
		"items": []
	})

	ok = TestAssertScript.is_true(
		world.state.bubbles.active_ids.size() == 1,
		"dedicated server should reject older sideband after a newer sideband has already been applied",
		prefix
	) and ok

	_cleanup_nodes([client])
	return ok


func _test_dedicated_server_accepts_monotonic_sideband_restore() -> bool:
	var client := ClientRuntimeScript.new()
	add_child(client)

	var config := _make_config()
	config.topology = "dedicated_server"
	client.configure(2)
	var prefix := "client_runtime_summary_snapshot_sync_test"
	var ok := true
	ok = TestAssertScript.is_true(client.start_match(config), "client runtime should start for dedicated monotonic sideband test", prefix) and ok
	if not ok:
		_cleanup_nodes([client])
		return false

	var world := client.prediction_controller.predicted_sim_world
	world.state.match_state.tick = 20
	if world.tick_runner != null:
		world.tick_runner.set_tick(20)

	client.ingest_network_message({
		"message_type": TransportMessageTypesScript.STATE_SUMMARY,
		"msg_type": TransportMessageTypesScript.STATE_SUMMARY,
		"tick": 2,
		"player_summary": [],
		"bubbles": [{
			"entity_id": 100,
			"generation": 1,
			"alive": true,
			"owner_player_id": 1,
			"bubble_type": 0,
			"cell_x": 2,
			"cell_y": 2,
			"spawn_tick": 2,
			"explode_tick": 62,
			"bubble_range": 1,
			"moving_state": 0,
			"move_dir_x": 0,
			"move_dir_y": 0,
			"pierce": false,
			"chain_triggered": false,
			"remote_group_id": 0,
			"ignore_player_ids": []
		}],
		"items": []
	})

	ok = TestAssertScript.is_true(
		world.state.bubbles.active_ids.size() == 1,
		"dedicated server should accept newer authoritative sideband even when predicted world is far ahead",
		prefix
	) and ok

	_cleanup_nodes([client])
	return ok


func _test_dedicated_server_applies_authoritative_walls_sideband_to_current_world() -> bool:
	var client := ClientRuntimeScript.new()
	add_child(client)

	var config := _make_config()
	config.topology = "dedicated_server"
	client.configure(2)
	var prefix := "client_runtime_summary_snapshot_sync_test"
	var ok := true
	ok = TestAssertScript.is_true(client.start_match(config), "client runtime should start for authoritative wall-sideband sync test", prefix) and ok
	if not ok:
		_cleanup_nodes([client])
		return false

	var world := client.prediction_controller.predicted_sim_world
	world.state.match_state.tick = 20
	if world.tick_runner != null:
		world.tick_runner.set_tick(20)

	var breakable_cell := _find_breakable_cell(world)
	ok = TestAssertScript.is_true(breakable_cell != Vector2i(-1, -1), "test map should provide at least one breakable cell", prefix) and ok
	if not ok:
		_cleanup_nodes([client])
		return false

	var before_tile_type := world.state.grid.get_static_cell(breakable_cell.x, breakable_cell.y).tile_type
	client.ingest_network_message({
		"message_type": TransportMessageTypesScript.STATE_SUMMARY,
		"msg_type": TransportMessageTypesScript.STATE_SUMMARY,
		"tick": 2,
		"player_summary": [],
		"bubbles": [],
		"items": [],
		"walls": [{
			"cell_x": breakable_cell.x,
			"cell_y": breakable_cell.y,
			"tile_type": TileConstants.TileType.EMPTY,
			"tile_flags": 0,
			"theme_variant": 0,
		}],
		"events": []
	})
	var after_tile_type := world.state.grid.get_static_cell(breakable_cell.x, breakable_cell.y).tile_type
	ok = TestAssertScript.is_true(
		before_tile_type == TileConstants.TileType.BREAKABLE_BLOCK and after_tile_type == TileConstants.TileType.EMPTY,
		"dedicated server should apply authoritative wall sideband to the current world",
		prefix
	) and ok

	_cleanup_nodes([client])
	return ok


func _make_config() -> BattleStartConfig:
	var mode_id := ModeCatalogScript.get_default_mode_id()
	var mode_metadata := ModeCatalogScript.get_mode_metadata(mode_id)
	var map_id := String(mode_metadata.get("default_map_id", MapCatalogScript.get_default_map_id()))
	var rule_set_id := String(mode_metadata.get("rule_set_id", RuleSetCatalogScript.get_default_rule_id()))
	var map_metadata := MapLoaderScript.load_map_metadata(map_id)
	var host_character_id := CharacterCatalogScript.get_default_character_id()
	var client_character_id := CharacterCatalogScript.get_default_character_id()
	var host_character_metadata := CharacterCatalogScript.get_character_metadata(host_character_id)
	var client_character_metadata := CharacterCatalogScript.get_character_metadata(client_character_id)
	var spawn_points: Array = map_metadata.get("spawn_points", [])

	var config := BattleStartConfigScript.new()
	config.room_id = "client_runtime_summary_snapshot_sync_room"
	config.match_id = "client_runtime_summary_snapshot_sync_match"
	config.map_id = map_id
	config.map_version = int(map_metadata.get("version", 1))
	config.map_content_hash = String(map_metadata.get("content_hash", ""))
	config.mode_id = mode_id
	config.rule_set_id = rule_set_id
	config.battle_seed = 20260408
	config.start_tick = 0
	config.match_duration_ticks = 30
	config.item_spawn_profile_id = String(map_metadata.get("item_spawn_profile_id", "default_items"))
	config.session_mode = "singleplayer_local"
	config.topology = "listen"
	config.local_peer_id = 2
	config.controlled_peer_id = 2
	config.owner_peer_id = 1
	config.player_slots = [
		{"peer_id": 1, "player_name": "Host", "slot_index": 0, "spawn_slot": 0, "character_id": host_character_id},
		{"peer_id": 2, "player_name": "Client", "slot_index": 1, "spawn_slot": 1, "character_id": client_character_id},
	]
	config.players = config.player_slots.duplicate(true)
	config.character_loadouts = [
		{"peer_id": 1, "character_id": host_character_id, "content_hash": String(host_character_metadata.get("content_hash", ""))},
		{"peer_id": 2, "character_id": client_character_id, "content_hash": String(client_character_metadata.get("content_hash", ""))},
	]
	config.spawn_assignments = [
		{"peer_id": 1, "slot_index": 0, "spawn_index": 0, "spawn_cell_x": spawn_points[0].x, "spawn_cell_y": spawn_points[0].y},
		{"peer_id": 2, "slot_index": 1, "spawn_index": 1, "spawn_cell_x": spawn_points[1].x, "spawn_cell_y": spawn_points[1].y},
	]
	config.sort_players()
	return config


func _cleanup_nodes(nodes: Array) -> void:
	for node in nodes:
		if node == null:
			continue
		if node.has_method("shutdown_runtime"):
			node.shutdown_runtime()
		if is_instance_valid(node):
			node.queue_free()


func _find_breakable_cell(world: SimWorld) -> Vector2i:
	if world == null or world.state == null or world.state.grid == null:
		return Vector2i(-1, -1)
	for y in range(world.state.grid.height):
		for x in range(world.state.grid.width):
			var cell = world.state.grid.get_static_cell(x, y)
			if cell.tile_type == TileConstants.TileType.BREAKABLE_BLOCK:
				return Vector2i(x, y)
	return Vector2i(-1, -1)
