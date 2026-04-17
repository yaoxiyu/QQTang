extends RefCounted

const NORMAL_LOADING_MODE := "normal_start"
const RESUME_LOADING_MODE := "resume_match"

var current_resume_snapshot = null
var current_loading_mode: String = NORMAL_LOADING_MODE


func set_state(resume_snapshot, loading_mode: String) -> void:
	current_resume_snapshot = resume_snapshot
	current_loading_mode = loading_mode if not loading_mode.is_empty() else NORMAL_LOADING_MODE


func apply_match_resume_payload(resume_snapshot) -> void:
	current_resume_snapshot = resume_snapshot
	current_loading_mode = RESUME_LOADING_MODE


func clear_resume_payload() -> void:
	current_resume_snapshot = null
	current_loading_mode = NORMAL_LOADING_MODE


func sync_front_context(front_context: RefCounted) -> void:
	if front_context == null:
		return
	front_context.current_resume_snapshot = current_resume_snapshot
	front_context.current_loading_mode = current_loading_mode
