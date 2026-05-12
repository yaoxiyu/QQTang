extends "res://tests/gut/base/qqt_unit_test.gd"

const ClientRuntimeScript = preload("res://network/session/runtime/client_runtime.gd")
const BattleStartConfigScript = preload("res://gameplay/battle/config/battle_start_config.gd")
const TransportMessageTypesScript = preload("res://network/transport/transport_message_types.gd")
const MapCatalogScript = preload("res://content/maps/catalog/map_catalog.gd")
const MapLoaderScript = preload("res://content/maps/runtime/map_loader.gd")
const ModeCatalogScript = preload("res://content/modes/catalog/mode_catalog.gd")
const RuleSetCatalogScript = preload("res://content/rulesets/catalog/rule_set_catalog.gd")


func test_build_local_input_message_sends_recent_input_batch() -> void:
	var runtime := ClientRuntimeScript.new()
	add_child(runtime)
	runtime.configure(2)
	runtime.configure_controlled_peer(2)
	assert_true(runtime.start_match(_make_config()))

	var latest_message: Dictionary = {}
	for index in range(8):
		latest_message = runtime.build_local_input_message({
			"move_x": 1 if index % 2 == 0 else 0,
			"move_y": 0,
			"action_bits": 1 if index == 7 else 0,
	})

	assert_eq(String(latest_message.get("message_type", "")), TransportMessageTypesScript.INPUT_BATCH)
	assert_eq(int(latest_message.get("wire_version", 0)), 2)
	assert_eq(int(latest_message.get("client_batch_seq", 0)), 8)
	assert_eq(int(latest_message.get("latest_tick", 0)), 13)
	assert_false(latest_message.has("tick"))
	assert_false(latest_message.has("frame"))
	var frames: Array = latest_message.get("frames", [])
	assert_lte(frames.size(), 8)
	assert_gt(frames.size(), 0)
	var first_tick := int(latest_message.get("first_tick", 0))
	var latest_frame := frames.back() as Dictionary
	assert_eq(first_tick + int(latest_frame.get("tick_delta", 0)), 13)
	assert_true((int(latest_frame.get("action_bits", 0)) & 1) != 0)
	assert_eq(int(runtime.build_metrics().get("input_lead_ticks", 0)), 6)

	runtime.shutdown_runtime()
	runtime.queue_free()


func test_place_action_is_redundantly_sent_after_edge() -> void:
	var runtime := ClientRuntimeScript.new()
	add_child(runtime)
	runtime.configure(2)
	runtime.configure_controlled_peer(2)
	assert_true(runtime.start_match(_make_config()))

	var first_message := runtime.build_local_input_message({
		"move_x": 0,
		"move_y": 0,
		"action_bits": 1,
	})
	var second_message := runtime.build_local_input_message({
		"move_x": 0,
		"move_y": 0,
		"action_bits": 0,
	})
	var third_message := runtime.build_local_input_message({
		"move_x": 0,
		"move_y": 0,
		"action_bits": 0,
	})
	var fourth_message := runtime.build_local_input_message({
		"move_x": 0,
		"move_y": 0,
		"action_bits": 0,
	})

	assert_true((int(((first_message.get("frames", []) as Array).back() as Dictionary).get("action_bits", 0)) & 1) != 0)
	assert_true((int(((second_message.get("frames", []) as Array).back() as Dictionary).get("action_bits", 0)) & 1) != 0)
	assert_true((int(((third_message.get("frames", []) as Array).back() as Dictionary).get("action_bits", 0)) & 1) != 0)
	assert_false((int(((fourth_message.get("frames", []) as Array).back() as Dictionary).get("action_bits", 0)) & 1) != 0)
	assert_eq(runtime.client_session.get_local_frame(int(first_message.get("latest_tick", 0))).action_bits, 1)

	runtime.shutdown_runtime()
	runtime.queue_free()


func test_runtime_input_lead_keeps_dedicated_minimum_after_opening_window() -> void:
	var runtime := ClientRuntimeScript.new()
	add_child(runtime)
	runtime.configure(2)
	runtime.configure_controlled_peer(2)
	var config := _make_config()
	config.opening_input_freeze_ticks = 0
	config.network_input_lead_ticks = 1
	assert_true(runtime.start_match(config))
	runtime.prediction_controller.authoritative_tick = 10

	runtime.build_local_input_message({"move_x": 1, "move_y": 0, "action_bits": 0})

	assert_eq(int(runtime.build_metrics().get("input_lead_ticks", 0)), 3)
	runtime.shutdown_runtime()
	runtime.queue_free()


func _make_config() -> BattleStartConfig:
	var mode_id := ModeCatalogScript.get_default_mode_id()
	var map_id := MapCatalogScript.get_default_map_id()
	var map_metadata := MapLoaderScript.load_map_metadata(map_id)
	var spawn_points: Array = map_metadata.get("spawn_points", [])
	var config := BattleStartConfigScript.new()
	config.room_id = "input_batch_room"
	config.match_id = "input_batch_match"
	config.map_id = map_id
	config.map_version = int(map_metadata.get("version", 1))
	config.map_content_hash = String(map_metadata.get("content_hash", ""))
	config.mode_id = mode_id
	config.rule_set_id = RuleSetCatalogScript.get_default_rule_id()
	config.battle_seed = 123
	config.start_tick = 0
	config.match_duration_ticks = 60
	config.item_spawn_profile_id = "default_items"
	config.session_mode = "network_client"
	config.topology = "dedicated_server"
	config.local_peer_id = 2
	config.controlled_peer_id = 2
	config.owner_peer_id = 1
	config.network_input_lead_ticks = 1
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
