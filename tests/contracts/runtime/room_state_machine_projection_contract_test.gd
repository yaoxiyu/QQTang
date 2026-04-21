extends "res://tests/gut/base/qqt_contract_test.gd"

const RoomSnapshotScript = preload("res://gameplay/battle/config/room_snapshot.gd")
const RoomMemberStateScript = preload("res://gameplay/battle/config/room_member_state.gd")

const ROOM_PROTO_PATH := "res://proto/qqt/room/v1/room_models.proto"
const ROOM_WS_ENCODER_PATH := "res://services/room_service/internal/wsapi/encoder.go"


func test_room_snapshot_contract_exposes_canonical_phase_and_capability_fields() -> void:
	var snapshot := RoomSnapshotScript.new()
	var serialized := snapshot.to_dict()
	var required_keys := [
		"room_phase",
		"room_phase_reason",
		"queue_phase",
		"queue_terminal_reason",
		"queue_status_text",
		"queue_error_code",
		"queue_user_message",
		"queue_entry_id",
		"battle_phase",
		"battle_terminal_reason",
		"battle_status_text",
		"can_toggle_ready",
		"can_start_manual_battle",
		"can_update_selection",
		"can_update_match_room_config",
		"can_enter_queue",
		"can_cancel_queue",
		"can_leave_room",
	]
	for key in required_keys:
		assert_true(serialized.has(key), "RoomSnapshot.to_dict must include canonical key: %s" % key)


func test_room_member_contract_exposes_member_phase() -> void:
	var member := RoomMemberStateScript.new()
	var serialized := member.to_dict()
	assert_true(serialized.has("member_phase"), "RoomMemberState.to_dict must include member_phase")


func test_room_proto_contract_declares_canonical_snapshot_fields() -> void:
	var proto_text := _read_text(ROOM_PROTO_PATH)
	assert_false(proto_text.is_empty(), "room_models.proto should be readable")

	var required_snippets := [
		"string member_phase",
		"string room_phase",
		"string room_phase_reason",
		"string queue_phase",
		"string queue_terminal_reason",
		"string queue_status_text",
		"string queue_error_code",
		"string queue_user_message",
		"string queue_entry_id",
		"bool can_toggle_ready",
		"bool can_start_manual_battle",
		"bool can_update_selection",
		"bool can_update_match_room_config",
		"bool can_enter_queue",
		"bool can_cancel_queue",
		"bool can_leave_room",
	]
	for snippet in required_snippets:
		assert_true(proto_text.find(snippet) >= 0, "room_models.proto must declare: %s" % snippet)


func test_room_ws_encoder_contract_projects_canonical_snapshot_fields() -> void:
	var encoder_text := _read_text(ROOM_WS_ENCODER_PATH)
	assert_false(encoder_text.is_empty(), "room ws encoder should be readable")

	var required_snippets := [
		"RoomPhase:",
		"RoomPhaseReason:",
		"QueuePhase:",
		"QueueTerminalReason:",
		"QueueStatusText:",
		"QueueErrorCode:",
		"QueueUserMessage:",
		"QueueEntryId:",
		"CanToggleReady:",
		"CanStartManualBattle:",
		"CanUpdateSelection:",
		"CanUpdateMatchRoomConfig:",
		"CanEnterQueue:",
		"CanCancelQueue:",
		"CanLeaveRoom:",
		"MemberPhase:",
		"entry.Phase =",
		"entry.TerminalReason =",
		"entry.StatusText =",
	]
	for snippet in required_snippets:
		assert_true(encoder_text.find(snippet) >= 0, "encoder.go must project canonical field: %s" % snippet)


func _read_text(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	return file.get_as_text()
