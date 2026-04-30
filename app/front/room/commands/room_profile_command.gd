class_name RoomProfileCommand
extends RefCounted

const RoomErrorMapperScript = preload("res://app/front/room/errors/room_error_mapper.gd")
const RoomSelectionPolicyScript = preload("res://app/front/room/room_selection_policy.gd")
const RoomUseCaseRuntimeStateScript = preload("res://app/front/room/room_use_case_runtime_state.gd")
const PlayerProfileStateScript = preload("res://app/front/profile/player_profile_state.gd")


func update_local_profile(
	app_runtime: Object,
	room_client_gateway: RefCounted,
	player_name: String,
	character_id: String,
	character_skin_id: String,
	bubble_style_id: String,
	bubble_skin_id: String,
	team_id: int = 1
) -> Dictionary:
	if app_runtime == null or app_runtime.room_session_controller == null:
		return RoomErrorMapperScript.to_front_error("ROOM_CONTROLLER_MISSING", "Room controller is not available")
	var effective_team_id := _resolve_effective_team_id(app_runtime, team_id)
	var result: Dictionary = app_runtime.room_session_controller.request_update_member_profile(
		int(app_runtime.local_peer_id),
		player_name,
		character_id,
		character_skin_id,
		bubble_style_id,
		bubble_skin_id,
		effective_team_id
	)
	if bool(result.get("ok", false)) and room_client_gateway != null and RoomUseCaseRuntimeStateScript.is_online_room(app_runtime):
		room_client_gateway.request_update_profile(player_name, character_id, character_skin_id, bubble_style_id, bubble_skin_id, effective_team_id)
	if bool(result.get("ok", false)):
		_remember_selected_character(app_runtime, character_id)
	return result


func _resolve_effective_team_id(app_runtime: Object, fallback_team_id: int) -> int:
	if not RoomUseCaseRuntimeStateScript.is_match_room(app_runtime):
		return fallback_team_id
	return RoomSelectionPolicyScript.resolve_locked_team_id(
		app_runtime.current_room_snapshot,
		app_runtime.current_room_entry_context,
		int(app_runtime.local_peer_id),
		fallback_team_id
	)


func _remember_selected_character(app_runtime: Object, character_id: String) -> void:
	if app_runtime == null or app_runtime.player_profile_state == null:
		return
	var normalized := PlayerProfileStateScript.resolve_default_character_id(character_id)
	app_runtime.player_profile_state.default_character_id = normalized
	if app_runtime.profile_repository != null and app_runtime.profile_repository.has_method("save_profile"):
		app_runtime.profile_repository.save_profile(app_runtime.player_profile_state)
