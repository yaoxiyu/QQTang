extends Node

const FrontRoomKindScript = preload("res://app/front/navigation/front_room_kind.gd")
const RoomServerStateScript = preload("res://network/session/runtime/room_server_state.gd")
const RoomSnapshotScript = preload("res://gameplay/battle/config/room_snapshot.gd")
const RoomSessionControllerScript = preload("res://network/session/room_session_controller.gd")
const TestAssert = preload("res://tests/helpers/test_assert.gd")

signal test_finished


func _ready() -> void:
	var prefix := "match_room_kind_state_test"
	var ok := true
	ok = TestAssert.is_true(FrontRoomKindScript.is_match_room("casual_match_room"), "casual match room should be match room", prefix) and ok
	ok = TestAssert.is_true(FrontRoomKindScript.is_match_room("ranked_match_room"), "ranked match room should be match room", prefix) and ok
	ok = TestAssert.is_true(FrontRoomKindScript.is_assigned_room("matchmade_room"), "matchmade room should be assigned room", prefix) and ok

	var state := RoomServerStateScript.new()
	state.ensure_room("ROOM-KIND", 1, "ranked_match_room", "")
	ok = TestAssert.is_true(state.is_match_room(), "server state should classify ranked room as match room", prefix) and ok
	ok = TestAssert.is_true(String(state.queue_type) == "ranked", "ranked room should initialize ranked queue type", prefix) and ok
	ok = TestAssert.is_true(String(state.selected_map_id).is_empty(), "match room should not keep map selection", prefix) and ok

	state.match_format_id = "2v2"
	state.required_party_size = 2
	state.selected_match_mode_ids = ["mode_classic"]
	state.room_queue_state = "queueing"
	state.room_queue_entry_id = "party_queue_alpha"
	state.room_queue_status_text = "Queueing"
	var roundtrip := RoomSnapshotScript.from_dict(state.build_snapshot().to_dict())
	ok = TestAssert.is_true(String(roundtrip.queue_type) == "ranked", "snapshot should preserve queue type", prefix) and ok
	ok = TestAssert.is_true(String(roundtrip.match_format_id) == "2v2", "snapshot should preserve match format", prefix) and ok
	ok = TestAssert.is_true(roundtrip.selected_match_mode_ids == ["mode_classic"], "snapshot should preserve selected mode pool", prefix) and ok
	ok = TestAssert.is_true(String(roundtrip.room_queue_entry_id) == "party_queue_alpha", "snapshot should preserve queue entry id", prefix) and ok

	var controller := RoomSessionControllerScript.new()
	add_child(controller)
	controller.apply_authoritative_snapshot(roundtrip)
	ok = TestAssert.is_true(String(controller.room_runtime_context.room_queue_state) == "queueing", "runtime context should receive queue state", prefix) and ok
	ok = TestAssert.is_true(String(controller.room_runtime_context.match_format_id) == "2v2", "runtime context should receive match format", prefix) and ok
	controller.queue_free()

	if ok:
		print("match_room_kind_state_test: PASS")
	test_finished.emit()
