class_name FrontRuntimeContext
extends RefCounted

var auth_session_state: AuthSessionState = null
var player_profile_state: PlayerProfileState = null
var front_settings_state: FrontSettingsState = null
var current_room_entry_context: RoomEntryContext = null
var pending_room_action: String = ""
var current_loading_mode: String = "normal_start"
var current_resume_snapshot = null


func clear_resume_payload() -> void:
	current_resume_snapshot = null
	current_loading_mode = "normal_start"
