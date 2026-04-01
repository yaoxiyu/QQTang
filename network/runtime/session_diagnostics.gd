class_name SessionDiagnostics
extends RefCounted

const RoomFlowStateScript = preload("res://network/session/runtime/room_flow_state.gd")
const SessionLifecycleStateScript = preload("res://network/session/runtime/session_lifecycle_state.gd")
const BattleFlowStateScript = preload("res://gameplay/battle/runtime/battle_flow_state.gd")


func build_runtime_dump(app_runtime: Node) -> Dictionary:
	if app_runtime == null:
		return {}

	var room_controller = app_runtime.room_session_controller if app_runtime != null else null
	var room_runtime_context = room_controller.room_runtime_context if room_controller != null else null
	var battle_bootstrap = app_runtime.current_battle_bootstrap if app_runtime != null else null
	var current_start_config = app_runtime.current_start_config if app_runtime != null else null
	var last_runtime_error: Dictionary = app_runtime.last_runtime_error.duplicate(true) if app_runtime != null and app_runtime.last_runtime_error is Dictionary else {}
	var room_last_error: Dictionary = room_runtime_context.last_error.duplicate(true) if room_runtime_context != null and room_runtime_context.last_error is Dictionary else {}
	var room_flow_state: int = room_controller.room_flow_state if room_controller != null else RoomFlowStateScript.Value.NONE
	var session_lifecycle_state: int = room_controller.session_lifecycle_state if room_controller != null else SessionLifecycleStateScript.Value.NONE
	var battle_flow_state: int = battle_bootstrap.battle_flow_state if battle_bootstrap != null else BattleFlowStateScript.Value.NONE

	return {
		"room_id": String(room_runtime_context.room_id if room_runtime_context != null else ""),
		"match_id": _resolve_match_id(app_runtime, room_runtime_context),
		"local_player_id": int(room_runtime_context.local_player_id if room_runtime_context != null else 0),
		"host_player_id": int(room_runtime_context.host_player_id if room_runtime_context != null else 0),
		"is_host": bool(room_runtime_context.is_host if room_runtime_context != null else false),
		"selected_map_id": String(room_runtime_context.selected_map_id if room_runtime_context != null else ""),
		"selected_rule_set_id": String(room_runtime_context.selected_rule_set_id if room_runtime_context != null else ""),
		"room_flow_state": room_flow_state,
		"room_flow_state_name": RoomFlowStateScript.state_to_string(room_flow_state),
		"session_lifecycle_state": session_lifecycle_state,
		"session_lifecycle_state_name": SessionLifecycleStateScript.state_to_string(session_lifecycle_state),
		"battle_flow_state": battle_flow_state,
		"battle_flow_state_name": BattleFlowStateScript.state_to_string(battle_flow_state),
		"completed_match_count": int(room_controller.completed_match_count if room_controller != null else 0),
		"last_completed_match_id": String(room_controller.last_completed_match_id if room_controller != null else ""),
		"battle_start_config": _build_start_config_dump(current_start_config),
		"room_runtime_context": room_runtime_context.to_dict() if room_runtime_context != null else {},
		"battle_context": battle_bootstrap.debug_dump_context() if battle_bootstrap != null and battle_bootstrap.has_method("debug_dump_context") else {},
		"last_runtime_error": last_runtime_error,
		"room_last_error": room_last_error,
	}


func build_room_debug_lines(app_runtime: Node, front_flow_state_name: String) -> PackedStringArray:
	var dump := build_runtime_dump(app_runtime)
	var lines := PackedStringArray([
		"Room: %s" % String(dump.get("room_id", "")),
		"Match: %s" % String(dump.get("match_id", "")),
		"Map: %s" % String(dump.get("selected_map_id", "")),
		"Rule: %s" % String(dump.get("selected_rule_set_id", "")),
		"RoomFlow: %s" % String(dump.get("room_flow_state_name", "UNKNOWN")),
		"SessionFlow: %s" % String(dump.get("session_lifecycle_state_name", "UNKNOWN")),
		"BattleFlow: %s" % String(dump.get("battle_flow_state_name", "UNKNOWN")),
		"FrontFlow: %s" % front_flow_state_name,
		"Completed: %d" % int(dump.get("completed_match_count", 0)),
	])
	var last_runtime_error: Dictionary = dump.get("last_runtime_error", {})
	if not last_runtime_error.is_empty():
		lines.append("Error: %s" % String(last_runtime_error.get("error_code", "")))
		lines.append("Hint: %s" % String(last_runtime_error.get("user_message", "")))
	return lines


func _build_start_config_dump(config: BattleStartConfig) -> Dictionary:
	if config == null:
		return {}
	return {
		"room_id": config.room_id,
		"match_id": config.match_id,
		"map_id": config.map_id,
		"map_version": config.map_version,
		"map_content_hash": config.map_content_hash,
		"rule_set_id": config.rule_set_id,
		"player_count": config.player_slots.size(),
		"player_slots": config.player_slots.duplicate(true),
		"spawn_assignments": config.spawn_assignments.duplicate(true),
		"battle_seed": config.battle_seed,
		"match_duration_ticks": config.match_duration_ticks,
		"item_spawn_profile_id": config.item_spawn_profile_id,
		"snapshot_interval": config.snapshot_interval,
		"checksum_interval": config.checksum_interval,
		"rollback_window": config.rollback_window,
	}


func _resolve_match_id(app_runtime: Node, room_runtime_context: RoomRuntimeContext) -> String:
	if app_runtime != null and app_runtime.current_start_config != null and not app_runtime.current_start_config.match_id.is_empty():
		return app_runtime.current_start_config.match_id
	if room_runtime_context != null:
		return room_runtime_context.pending_match_id
	return ""


