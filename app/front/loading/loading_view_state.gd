class_name LoadingViewState
extends RefCounted

var map_display_name: String = ""
var rule_display_name: String = ""
var mode_display_name: String = ""
var item_brief: String = ""
var character_brief: String = ""
var bubble_brief: String = ""
var player_lines: Array[String] = []
var loading_phase_text: String = ""
var waiting_summary_text: String = ""
var status_message: String = ""
var is_commit_ready: bool = false

# Phase17: Resume mode fields
var loading_mode: String = "normal_start"
var resume_hint_text: String = ""
var resume_match_id: String = ""


func to_dict() -> Dictionary:
	return {
		"map_display_name": map_display_name,
		"rule_display_name": rule_display_name,
		"mode_display_name": mode_display_name,
		"item_brief": item_brief,
		"character_brief": character_brief,
		"bubble_brief": bubble_brief,
		"player_lines": player_lines.duplicate(),
		"loading_phase_text": loading_phase_text,
		"waiting_summary_text": waiting_summary_text,
		"status_message": status_message,
		"is_commit_ready": is_commit_ready,
		"loading_mode": loading_mode,
		"resume_hint_text": resume_hint_text,
		"resume_match_id": resume_match_id,
	}
