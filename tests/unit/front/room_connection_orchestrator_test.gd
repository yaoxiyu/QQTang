extends "res://tests/gut/base/qqt_unit_test.gd"

const RoomConnectionOrchestratorScript = preload("res://app/front/room/room_connection_orchestrator.gd")
const RoomEntryContextScript = preload("res://app/front/room/room_entry_context.gd")
const FrontRoomKindScript = preload("res://app/front/navigation/front_room_kind.gd")
const MapSelectionCatalogScript = preload("res://content/maps/catalog/map_selection_catalog.gd")


class FakeAuthSessionState:
	extends RefCounted
	var device_session_id := "device_alpha"


class FakePlayerProfileState:
	extends RefCounted
	var nickname := "PlayerAlpha"
	var preferred_map_id := ""
	var preferred_mode_id := ""
	var default_character_id := "10101"
	var default_character_skin_id := ""
	var default_bubble_style_id := "bubble_round"
	var default_bubble_skin_id := ""


class FakeRuntime:
	extends RefCounted
	var auth_session_state := FakeAuthSessionState.new()
	var player_profile_state := FakePlayerProfileState.new()
	var client_room_runtime = null


func test_build_connection_config_preserves_ticket_and_resolves_selection() -> void:
	var runtime := FakeRuntime.new()
	var preferred_map_id := MapSelectionCatalogScript.get_default_custom_room_map_id()
	runtime.player_profile_state.preferred_map_id = preferred_map_id
	var entry_context := RoomEntryContextScript.new()
	entry_context.room_kind = FrontRoomKindScript.PRIVATE_ROOM
	entry_context.server_host = "127.0.0.1"
	entry_context.server_port = 9010
	entry_context.room_ticket = "ticket_alpha"
	entry_context.room_ticket_id = "ticket_id_alpha"
	entry_context.account_id = "account_alpha"
	entry_context.profile_id = "profile_alpha"

	var result := RoomConnectionOrchestratorScript.build_connection_config(runtime, entry_context)
	var config = result.get("config", null)

	assert_not_null(config, "connection config should be built")
	assert_eq(config.server_host, "127.0.0.1", "connection config should keep host")
	assert_eq(config.server_port, 9010, "connection config should keep port")
	assert_eq(config.room_ticket, "ticket_alpha", "connection config should keep room ticket")
	assert_eq(config.device_session_id, "device_alpha", "connection config should keep device session")
	assert_eq(config.selected_map_id, preferred_map_id, "connection config should preserve valid preferred map")


func test_match_room_connection_config_keeps_selection_blank() -> void:
	var runtime := FakeRuntime.new()
	var entry_context := RoomEntryContextScript.new()
	entry_context.room_kind = FrontRoomKindScript.CASUAL_MATCH_ROOM
	entry_context.match_format_id = "2v2"
	entry_context.selected_match_mode_ids = ["mode_classic"]

	var result := RoomConnectionOrchestratorScript.build_connection_config(runtime, entry_context)
	var config = result.get("config", null)

	assert_not_null(config, "match room connection config should be built")
	assert_eq(config.selected_map_id, "", "match room connection should not send map selection")
	assert_eq(config.selected_rule_set_id, "", "match room connection should not send rule selection")
	assert_eq(config.selected_mode_id, "", "match room connection should not send mode selection")
	assert_eq(config.match_format_id, "2v2", "match room connection should preserve match format")
	assert_eq(config.selected_mode_ids, ["mode_classic"], "match room connection should preserve selected mode pool")
