extends "res://tests/gut/base/qqt_integration_test.gd"

const ClientRuntimeScript = preload("res://network/session/runtime/client_runtime.gd")
const AuthorityRuntimeScript = preload("res://network/session/runtime/authority_runtime.gd")
const BattleStartConfigScript = preload("res://gameplay/battle/config/battle_start_config.gd")
const TransportMessageTypesScript = preload("res://network/transport/transport_message_types.gd")
const MapCatalogScript = preload("res://content/maps/catalog/map_catalog.gd")
const MapLoaderScript = preload("res://content/maps/runtime/map_loader.gd")
const ModeCatalogScript = preload("res://content/modes/catalog/mode_catalog.gd")
const RuleSetCatalogScript = preload("res://content/rulesets/catalog/rule_set_catalog.gd")


func test_input_batch_redundancy_recovers_recent_dropped_input_frame() -> void:
	var config := _make_config()
	var client: ClientRuntime = ClientRuntimeScript.new()
	var authority: AuthorityRuntime = AuthorityRuntimeScript.new()
	add_child(client)
	add_child(authority)
	client.configure(2)
	client.configure_controlled_peer(2)
	authority.configure(1)
	assert_true(client.start_match(config))
	assert_true(authority.start_match(config))

	var messages: Array[Dictionary] = []
	for index in range(8):
		messages.append(client.build_local_input_message({
			"move_x": 1,
			"move_y": 0,
			"action_bits": 0,
		}))
	var dropped_tick := 6
	var recovery_message: Dictionary = messages[7]
	assert_eq(String(recovery_message.get("message_type", "")), TransportMessageTypesScript.INPUT_BATCH)
	authority.ingest_network_message(recovery_message)

	var recovered := authority.server_session.active_match.input_buffer.get_input(2, dropped_tick)
	assert_eq(recovered.peer_id, 2)
	assert_eq(recovered.tick_id, dropped_tick)
	assert_eq(recovered.move_x, 0)

	client.shutdown_runtime()
	authority.shutdown_runtime()
	client.queue_free()
	authority.queue_free()


func _make_config() -> BattleStartConfig:
	var mode_id := ModeCatalogScript.get_default_mode_id()
	var map_id := MapCatalogScript.get_default_map_id()
	var map_metadata := MapLoaderScript.load_map_metadata(map_id)
	var spawn_points: Array = map_metadata.get("spawn_points", [])
	var config := BattleStartConfigScript.new()
	config.room_id = "input_batch_redundancy_room"
	config.match_id = "input_batch_redundancy_match"
	config.map_id = map_id
	config.map_version = int(map_metadata.get("version", 1))
	config.map_content_hash = String(map_metadata.get("content_hash", ""))
	config.mode_id = mode_id
	config.rule_set_id = RuleSetCatalogScript.get_default_rule_id()
	config.battle_seed = 20260425
	config.start_tick = 0
	config.opening_input_freeze_ticks = 0
	config.network_input_lead_ticks = 1
	config.match_duration_ticks = 120
	config.item_spawn_profile_id = String(map_metadata.get("item_spawn_profile_id", "default_items"))
	config.session_mode = "singleplayer_local"
	config.topology = "listen"
	config.local_peer_id = 2
	config.controlled_peer_id = 2
	config.owner_peer_id = 1
	config.player_slots = [
		{"peer_id": 1, "player_name": "Host", "slot_index": 0, "spawn_slot": 0, "character_id": "hero_1", "team_id": 1},
		{"peer_id": 2, "player_name": "Client", "slot_index": 1, "spawn_slot": 1, "character_id": "hero_2", "team_id": 2},
	]
	config.players = config.player_slots.duplicate(true)
	config.spawn_assignments = [
		{"peer_id": 1, "slot_index": 0, "spawn_index": 0, "spawn_cell_x": spawn_points[0].x, "spawn_cell_y": spawn_points[0].y},
		{"peer_id": 2, "slot_index": 1, "spawn_index": 1, "spawn_cell_x": spawn_points[1].x, "spawn_cell_y": spawn_points[1].y},
	]
	config.sort_players()
	return config
