extends "res://tests/gut/base/qqt_unit_test.gd"

const RoomReconnectCoordinatorScript = preload("res://app/front/room/room_reconnect_coordinator.gd")
const RoomEntryContextScript = preload("res://app/front/room/room_entry_context.gd")
const FrontSettingsStateScript = preload("res://app/front/profile/front_settings_state.gd")
const FrontTopologyScript = preload("res://app/front/navigation/front_topology.gd")


class FakeSettingsRepository:
	extends RefCounted
	var save_count := 0

	func save_settings(_state) -> void:
		save_count += 1


class FakeRuntime:
	extends RefCounted
	var front_settings_state := FrontSettingsStateScript.new()
	var front_settings_repository := FakeSettingsRepository.new()
	var current_room_entry_context = null
	var applied_resume := false

	func apply_match_resume_payload(_config, _snapshot) -> void:
		applied_resume = true


func test_authoritative_snapshot_updates_reconnect_ticket() -> void:
	var runtime := FakeRuntime.new()
	var entry_context := RoomEntryContextScript.new()
	entry_context.server_host = "10.0.0.1"
	entry_context.server_port = 9100
	entry_context.topology = FrontTopologyScript.DEDICATED_SERVER
	runtime.current_room_entry_context = entry_context
	var snapshot := RoomSnapshot.new()
	snapshot.topology = FrontTopologyScript.DEDICATED_SERVER
	snapshot.room_id = "ROOM_ALPHA"
	snapshot.room_kind = "private_room"
	snapshot.room_display_name = "Room Alpha"
	snapshot.match_active = true

	RoomReconnectCoordinatorScript.apply_authoritative_snapshot(runtime, snapshot)

	assert_eq(runtime.front_settings_state.reconnect_room_id, "ROOM_ALPHA", "snapshot should write reconnect room id")
	assert_eq(runtime.front_settings_state.reconnect_host, "10.0.0.1", "snapshot should keep current room host")
	assert_eq(runtime.front_settings_state.reconnect_port, 9100, "snapshot should keep current room port")
	assert_eq(runtime.front_settings_state.reconnect_state, "active_match", "active match snapshot should mark active match")
	assert_eq(runtime.front_settings_repository.save_count, 1, "snapshot update should save settings")


func test_room_member_session_updates_resume_fields() -> void:
	var runtime := FakeRuntime.new()
	var payload := {
		"room_id": "ROOM_BRAVO",
		"room_kind": "public_room",
		"room_display_name": "Room Bravo",
		"member_id": "member_bravo",
		"reconnect_token": "token_bravo",
	}

	RoomReconnectCoordinatorScript.apply_room_member_session(runtime, payload)

	assert_eq(runtime.front_settings_state.reconnect_room_id, "ROOM_BRAVO", "member session should write room id")
	assert_eq(runtime.front_settings_state.reconnect_member_id, "member_bravo", "member session should write member id")
	assert_eq(runtime.front_settings_state.reconnect_token, "token_bravo", "member session should write token")
	assert_eq(runtime.front_settings_state.reconnect_state, "room_only", "member session should keep room only state")


func test_resume_reject_clear_is_limited_to_resume_flow_errors() -> void:
	var runtime := FakeRuntime.new()
	runtime.front_settings_state.reconnect_room_id = "ROOM_OLD"
	runtime.front_settings_state.reconnect_member_id = "member_old"
	runtime.front_settings_state.reconnect_token = "token_old"
	var entry_context := RoomEntryContextScript.new()
	entry_context.use_resume_flow = true

	assert_true(
		RoomReconnectCoordinatorScript.should_clear_pending_reconnect_ticket(entry_context, "RECONNECT_TOKEN_INVALID"),
		"invalid resume token should clear ticket"
	)
	assert_false(
		RoomReconnectCoordinatorScript.should_clear_pending_reconnect_ticket(entry_context, "ROOM_CONNECT_TIMEOUT"),
		"transport timeout should not clear ticket"
	)

	RoomReconnectCoordinatorScript.clear_reconnect_ticket_after_rejected_resume(runtime, "RECONNECT_TOKEN_INVALID")

	assert_eq(runtime.front_settings_state.reconnect_room_id, "", "clearing should reset room id")
	assert_eq(runtime.front_settings_state.reconnect_member_id, "", "clearing should reset member id")
	assert_eq(runtime.front_settings_state.reconnect_token, "", "clearing should reset token")
