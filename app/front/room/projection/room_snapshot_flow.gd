class_name RoomSnapshotFlow
extends RefCounted

const RoomPhaseToFrontFlowAdapterScript = preload("res://app/front/room/room_phase_to_front_flow_adapter.gd")
const RoomReconnectCoordinatorScript = preload("res://app/front/room/room_reconnect_coordinator.gd")
const RoomSnapshotProjectorScript = preload("res://app/front/room/projection/room_snapshot_projector.gd")
const RoomCapabilityProjectorScript = preload("res://app/front/room/projection/room_capability_projector.gd")
const RoomMemberProjectorScript = preload("res://app/front/room/projection/room_member_projector.gd")
const RoomResumeFlowScript = preload("res://app/front/room/recovery/room_resume_flow.gd")
const ViewRevisionGuardScript = preload("res://app/front/common/view_revision_guard.gd")
const RoomSnapshotValidityScript = preload("res://app/front/room/room_snapshot_validity.gd")

var _snapshot_projector: RefCounted = RoomSnapshotProjectorScript.new()
var _capability_projector: RefCounted = RoomCapabilityProjectorScript.new()
var _member_projector: RefCounted = RoomMemberProjectorScript.new()
var _resume_flow: RefCounted = RoomResumeFlowScript.new()
var _projection_revision_guard: RefCounted = ViewRevisionGuardScript.new()


func consume_authoritative_snapshot(app_runtime: Object, snapshot: RoomSnapshot, previous_view_state: Dictionary = {}, cache: RefCounted = null, context: Dictionary = {}) -> Dictionary:
	if app_runtime == null or app_runtime.room_session_controller == null:
		return {}
	if not RoomSnapshotValidityScript.can_apply_authoritative(snapshot, cache, context):
		return {
			"view_state": previous_view_state,
			"resume_context": _resume_flow.build_resume_context(previous_view_state),
			"projection_skipped": true,
			"skip_reason": "invalid_or_placeholder_snapshot",
		}
	app_runtime.room_session_controller.apply_authoritative_snapshot(snapshot)
	app_runtime.current_room_snapshot = app_runtime.room_session_controller.build_room_snapshot() if snapshot != null else null
	if _should_skip_projection(snapshot):
		var cached_resume_context: Dictionary = _resume_flow.build_resume_context(previous_view_state)
		return {
			"view_state": previous_view_state,
			"resume_context": cached_resume_context,
			"projection_skipped": true,
		}
	var projected_view_state := project_snapshot(snapshot, previous_view_state)
	var resume_context: Dictionary = _resume_flow.build_resume_context(projected_view_state)
	if app_runtime.front_flow != null:
		RoomPhaseToFrontFlowAdapterScript.apply(app_runtime.front_flow, snapshot)
	RoomReconnectCoordinatorScript.apply_authoritative_snapshot(app_runtime, snapshot)
	return {
		"view_state": projected_view_state,
		"resume_context": resume_context,
		"projection_skipped": false,
	}


func reset_revision_guard() -> void:
	_projection_revision_guard.reset()


func project_snapshot(snapshot: RoomSnapshot, previous_view_state: Dictionary = {}) -> Dictionary:
	var projection_source := _snapshot_to_projection_source(snapshot)
	if projection_source.is_empty():
		return {}
	projection_source["members"] = _member_projector.project(projection_source)
	projection_source["capabilities"] = _capability_projector.project(projection_source)
	return _snapshot_projector.build_view_state(projection_source, previous_view_state)


func _snapshot_to_projection_source(snapshot: RoomSnapshot) -> Dictionary:
	if snapshot == null:
		return {}
	return {
		"room_id": String(snapshot.room_id),
		"phase": String(snapshot.room_phase),
		"revision": int(snapshot.snapshot_revision),
		"match_id": String(snapshot.current_assignment_id),
		"members": snapshot.members,
		"capabilities": {
			"can_enter_queue": bool(snapshot.can_enter_queue),
			"can_cancel_queue": bool(snapshot.can_cancel_queue),
			"all_ready": bool(snapshot.all_ready),
			"battle_entry_ready": bool(snapshot.battle_entry_ready),
		},
	}


func _should_skip_projection(snapshot: RoomSnapshot) -> bool:
	if snapshot == null:
		_projection_revision_guard.reset()
		return false
	var room_id := String(snapshot.room_id)
	var revision := int(snapshot.snapshot_revision)
	if room_id.is_empty() and revision <= 0:
		return false
	return _projection_revision_guard.should_skip(room_id, revision)
