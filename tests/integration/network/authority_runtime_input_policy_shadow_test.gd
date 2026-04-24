extends "res://tests/gut/base/qqt_integration_test.gd"

const FrontRoomKindScript = preload("res://app/front/navigation/front_room_kind.gd")
const FrontTopologyScript = preload("res://app/front/navigation/front_topology.gd")
const MatchStartCoordinatorScript = preload("res://network/session/match_start_coordinator.gd")
const AuthorityRuntimeScript = preload("res://network/session/runtime/authority_runtime.gd")
const MapCatalogScript = preload("res://content/maps/catalog/map_catalog.gd")
const ModeCatalogScript = preload("res://content/modes/catalog/mode_catalog.gd")
const RuleSetCatalogScript = preload("res://content/rulesets/catalog/rule_set_catalog.gd")
const NativeFeatureFlagsScript = preload("res://gameplay/native_bridge/native_feature_flags.gd")
const TransportMessageTypesScript = preload("res://network/transport/transport_message_types.gd")


func test_authority_runtime_native_input_policy_shadow_matches_gdscript_retarget() -> void:
	var old_enabled := NativeFeatureFlagsScript.enable_native_input_buffer
	var old_shadow := NativeFeatureFlagsScript.enable_native_input_buffer_shadow
	var old_execute := NativeFeatureFlagsScript.enable_native_input_buffer_execute
	NativeFeatureFlagsScript.enable_native_input_buffer = true
	NativeFeatureFlagsScript.enable_native_input_buffer_shadow = true
	NativeFeatureFlagsScript.enable_native_input_buffer_execute = false

	var coordinator := MatchStartCoordinatorScript.new()
	var authority := AuthorityRuntimeScript.new()
	add_child(coordinator)
	add_child(authority)
	var config := coordinator.build_start_config(_make_room_snapshot())
	config.opening_input_freeze_ticks = 0
	config.sort_players()
	assert_true(authority.start_match(config))

	authority.ingest_network_message(_input_message(2, 2, 2))
	var future_metrics := authority.get_native_input_policy_shadow_metrics()
	assert_true(bool(future_metrics.get("shadow_equal", false)))
	assert_eq(int(future_metrics.get("shadow_mismatch_count", 0)), 0)

	authority.ingest_network_message(_input_message(2, 0, 3))
	var late_metrics := authority.get_native_input_policy_shadow_metrics()
	assert_true(bool(late_metrics.get("shadow_equal", false)))
	assert_eq(int(late_metrics.get("shadow_mismatch_count", 0)), 0)
	assert_eq(int(late_metrics.get("shadow_checked_count", 0)), 2)

	authority.shutdown_runtime()
	authority.queue_free()
	coordinator.queue_free()
	NativeFeatureFlagsScript.enable_native_input_buffer = old_enabled
	NativeFeatureFlagsScript.enable_native_input_buffer_shadow = old_shadow
	NativeFeatureFlagsScript.enable_native_input_buffer_execute = old_execute


func test_authority_runtime_native_input_policy_execute_drops_stale_and_too_late_frames() -> void:
	var old_enabled := NativeFeatureFlagsScript.enable_native_input_buffer
	var old_shadow := NativeFeatureFlagsScript.enable_native_input_buffer_shadow
	var old_execute := NativeFeatureFlagsScript.enable_native_input_buffer_execute
	NativeFeatureFlagsScript.enable_native_input_buffer = true
	NativeFeatureFlagsScript.enable_native_input_buffer_shadow = true
	NativeFeatureFlagsScript.enable_native_input_buffer_execute = true

	var coordinator := MatchStartCoordinatorScript.new()
	var authority := AuthorityRuntimeScript.new()
	add_child(coordinator)
	add_child(authority)
	var config := coordinator.build_start_config(_make_room_snapshot())
	config.opening_input_freeze_ticks = 0
	config.sort_players()
	assert_true(authority.start_match(config))

	authority.ingest_network_message(_input_message(2, 2, 10))
	authority.ingest_network_message(_input_message(2, 2, 9))
	authority.ingest_network_message(_input_message(2, -5, 11))

	var metrics := authority.get_native_input_policy_shadow_metrics()
	var native_metrics: Dictionary = metrics.get("native_buffer_metrics", {})
	assert_true(int(native_metrics.get("stale_seq_drop_count", 0)) >= 1)
	assert_true(int(native_metrics.get("too_late_drop_count", 0)) >= 1)

	authority.shutdown_runtime()
	authority.queue_free()
	coordinator.queue_free()
	NativeFeatureFlagsScript.enable_native_input_buffer = old_enabled
	NativeFeatureFlagsScript.enable_native_input_buffer_shadow = old_shadow
	NativeFeatureFlagsScript.enable_native_input_buffer_execute = old_execute


func _input_message(peer_id: int, tick_id: int, seq: int) -> Dictionary:
	return {
		"message_type": TransportMessageTypesScript.INPUT_FRAME,
		"sender_peer_id": peer_id,
		"frame": {
			"peer_id": peer_id,
			"tick_id": tick_id,
			"seq": seq,
			"move_x": 1,
			"move_y": 0,
			"action_place": false,
			"action_skill1": false,
			"action_skill2": false,
		},
	}


func _make_room_snapshot() -> RoomSnapshot:
	var snapshot := RoomSnapshot.new()
	snapshot.room_id = "authority_runtime_input_policy_shadow_room"
	snapshot.room_kind = FrontRoomKindScript.PRACTICE
	snapshot.topology = FrontTopologyScript.LOCAL
	snapshot.owner_peer_id = 1
	snapshot.selected_map_id = MapCatalogScript.get_default_map_id()
	snapshot.rule_set_id = RuleSetCatalogScript.get_default_rule_id()
	snapshot.mode_id = ModeCatalogScript.get_default_mode_id()
	snapshot.min_start_players = 1
	snapshot.all_ready = true
	snapshot.max_players = 2

	var host := RoomMemberState.new()
	host.peer_id = 1
	host.player_name = "Host"
	host.ready = true
	host.slot_index = 0
	host.character_id = "hero_1"
	host.team_id = 1
	snapshot.members.append(host)

	var client := RoomMemberState.new()
	client.peer_id = 2
	client.player_name = "Client"
	client.ready = true
	client.slot_index = 1
	client.character_id = "hero_2"
	client.team_id = 2
	snapshot.members.append(client)
	return snapshot
