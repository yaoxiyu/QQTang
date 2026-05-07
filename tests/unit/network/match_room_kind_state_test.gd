extends "res://tests/gut/base/qqt_unit_test.gd"

const FrontRoomKindScript = preload("res://app/front/navigation/front_room_kind.gd")
const RoomServerStateScript = preload("res://network/session/runtime/room_server_state.gd")
const RoomSnapshotScript = preload("res://gameplay/battle/config/room_snapshot.gd")
const RoomSessionControllerScript = preload("res://network/session/room_session_controller.gd")
const RoomFlowStateScript = preload("res://network/session/runtime/room_flow_state.gd")
const SessionLifecycleStateScript = preload("res://network/session/runtime/session_lifecycle_state.gd")



func test_main() -> void:
	var prefix := "match_room_kind_state_test"
	var ok := true
	ok = qqt_check(FrontRoomKindScript.is_match_room("casual_match_room"), "casual match room should be match room", prefix) and ok
	ok = qqt_check(FrontRoomKindScript.is_match_room("ranked_match_room"), "ranked match room should be match room", prefix) and ok

	var state := RoomServerStateScript.new()
	state.ensure_room("ROOM-KIND", 1, "ranked_match_room", "")
	ok = qqt_check(state.is_match_room(), "server state should classify ranked room as match room", prefix) and ok
	ok = qqt_check(String(state.queue_type) == "ranked", "ranked room should initialize ranked queue type", prefix) and ok
	ok = qqt_check(String(state.selected_map_id).is_empty(), "match room should not keep map selection", prefix) and ok

	state.match_format_id = "2v2"
	state.required_party_size = 2
	state.selected_match_mode_ids = ["box"]
	state.room_queue_state = "queueing"
	state.room_queue_entry_id = "party_queue_alpha"
	state.room_queue_status_text = "Queueing"
	var roundtrip := RoomSnapshotScript.from_dict(state.build_snapshot().to_dict())
	roundtrip.snapshot_revision = 1
	roundtrip.can_toggle_ready = true
	roundtrip.can_update_match_room_config = true
	roundtrip.can_enter_queue = false
	roundtrip.members[0].member_phase = "idle"
	ok = qqt_check(String(roundtrip.queue_type) == "ranked", "snapshot should preserve queue type", prefix) and ok
	ok = qqt_check(String(roundtrip.match_format_id) == "2v2", "snapshot should preserve match format", prefix) and ok
	ok = qqt_check(roundtrip.selected_match_mode_ids == ["box"], "snapshot should preserve selected mode pool", prefix) and ok
	ok = qqt_check(String(roundtrip.room_queue_entry_id) == "party_queue_alpha", "snapshot should preserve queue entry id", prefix) and ok

	var controller := RoomSessionControllerScript.new()
	add_child(controller)
	controller.apply_authoritative_snapshot(roundtrip)
	var rebuilt_snapshot := controller.build_room_snapshot()
	ok = qqt_check(rebuilt_snapshot.can_toggle_ready, "rebuilt snapshot should preserve can_toggle_ready", prefix) and ok
	ok = qqt_check(rebuilt_snapshot.can_update_match_room_config, "rebuilt snapshot should preserve can_update_match_room_config", prefix) and ok
	ok = qqt_check(not rebuilt_snapshot.can_enter_queue, "rebuilt snapshot should preserve can_enter_queue=false", prefix) and ok
	ok = qqt_check(String(rebuilt_snapshot.members[0].member_phase) == "idle", "rebuilt snapshot should preserve member_phase", prefix) and ok
	ok = qqt_check(String(controller.room_runtime_context.room_queue_state) == "queueing", "runtime context should receive queue state", prefix) and ok
	ok = qqt_check(String(controller.room_runtime_context.match_format_id) == "2v2", "runtime context should receive match format", prefix) and ok

	var owner_local_snapshot := RoomSnapshotScript.new()
	owner_local_snapshot.room_id = "ROOM-LOCAL-AUTH"
	owner_local_snapshot.room_kind = "private_room"
	owner_local_snapshot.topology = "dedicated_server"
	owner_local_snapshot.owner_peer_id = 101
	owner_local_snapshot.snapshot_revision = 10
	owner_local_snapshot.can_start_manual_battle = true
	var local_owner := RoomMemberState.new()
	local_owner.peer_id = 101
	local_owner.is_owner = true
	local_owner.is_local_player = true
	var remote_guest := RoomMemberState.new()
	remote_guest.peer_id = 202
	remote_guest.ready = true
	owner_local_snapshot.members = [local_owner, remote_guest]
	controller.set_local_player_id(1)
	controller.apply_authoritative_snapshot(owner_local_snapshot)
	var owner_rebuilt_snapshot := controller.build_room_snapshot()
	ok = qqt_check(
		int(controller.room_runtime_context.local_player_id) == 101,
		"authoritative local member should replace stale app local peer id",
		prefix
	) and ok
	ok = qqt_check(
		bool(owner_rebuilt_snapshot.members[0].is_local_player) and bool(owner_rebuilt_snapshot.members[0].is_owner),
		"rebuilt snapshot should preserve authoritative local owner identity",
		prefix
	) and ok
	ok = qqt_check(
		controller.get_start_match_blocker(1).is_empty(),
		"start blocker should resolve stale app peer id to authoritative local owner",
		prefix
	) and ok

	roundtrip.room_phase = "battle_entry_ready"
	roundtrip.snapshot_revision = 11
	controller.apply_authoritative_snapshot(roundtrip)
	ok = qqt_check(
		int(controller.room_runtime_context.room_flow_state) == RoomFlowStateScript.Value.MATCH_LOADING,
		"canonical battle_entry_ready should drive room flow to MATCH_LOADING",
		prefix
	) and ok
	ok = qqt_check(
		int(controller.room_runtime_context.session_lifecycle_state) == SessionLifecycleStateScript.Value.MATCH_LOADING,
		"canonical battle_entry_ready should drive session lifecycle to MATCH_LOADING",
		prefix
	) and ok
	roundtrip.room_phase = "in_battle"
	roundtrip.battle_phase = "active"
	roundtrip.match_active = true
	roundtrip.snapshot_revision = 12
	controller.apply_authoritative_snapshot(roundtrip)
	ok = qqt_check(
		int(controller.room_runtime_context.room_flow_state) == RoomFlowStateScript.Value.IN_BATTLE,
		"canonical in_battle should drive room flow to IN_BATTLE",
		prefix
	) and ok
	roundtrip.room_phase = "idle"
	roundtrip.battle_phase = "active"
	roundtrip.match_active = false
	roundtrip.snapshot_revision = 9
	controller.apply_authoritative_snapshot(roundtrip)
	ok = qqt_check(
		int(controller.room_runtime_context.room_flow_state) == RoomFlowStateScript.Value.IN_BATTLE,
		"lower revision idle snapshot must not downgrade active battle room flow",
		prefix
	) and ok
	ok = qqt_check(
		int(controller.room_runtime_context.session_lifecycle_state) == SessionLifecycleStateScript.Value.MATCH_ACTIVE,
		"lower revision idle snapshot must not downgrade active battle lifecycle",
		prefix
	) and ok
	var preserved_snapshot := controller.build_room_snapshot()
	ok = qqt_check(bool(preserved_snapshot.match_active), "preserved active battle snapshot should keep match_active", prefix) and ok
	ok = qqt_check(String(preserved_snapshot.room_phase) == "in_battle", "preserved active battle snapshot should keep in_battle phase", prefix) and ok
	roundtrip.room_phase = "returning_to_room"
	roundtrip.battle_phase = "returning"
	roundtrip.snapshot_revision = 13
	controller.apply_authoritative_snapshot(roundtrip)
	roundtrip.room_phase = "idle"
	roundtrip.battle_phase = "completed"
	roundtrip.snapshot_revision = 14
	controller.apply_authoritative_snapshot(roundtrip)
	ok = qqt_check(
		int(controller.room_runtime_context.room_flow_state) == RoomFlowStateScript.Value.IN_ROOM,
		"completed idle snapshot after returning should restore room flow",
		prefix
	) and ok
	controller.queue_free()
