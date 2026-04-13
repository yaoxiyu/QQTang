class_name LobbyViewState
extends RefCounted

var account_id: String = ""
var profile_id: String = ""
var auth_mode: String = ""
var session_state: String = ""
var profile_source: String = ""
var last_sync_msec: int = 0
var profile_name: String = ""
var default_character_id: String = ""
var default_character_skin_id: String = ""
var default_bubble_style_id: String = ""
var default_bubble_skin_id: String = ""
var last_server_host: String = "127.0.0.1"
var last_server_port: int = 9000
var last_room_id: String = ""
var reconnect_room_id: String = ""
var reconnect_host: String = ""
var reconnect_port: int = 0

# Phase16: Reconnect ticket extension
var reconnect_room_kind: String = ""
var reconnect_room_display_name: String = ""
var reconnect_topology: String = ""
var reconnect_match_id: String = ""

# Phase17: Member session resume ticket
var reconnect_member_id: String = ""
var reconnect_token: String = ""
var reconnect_state: String = ""
var reconnect_resume_deadline_msec: int = 0

var preferred_map_id: String = ""
var preferred_rule_id: String = ""
var preferred_mode_id: String = ""
var current_season_id: String = ""
var current_rating: int = 0
var current_rank_tier: String = ""
var career_total_matches: int = 0
var career_total_wins: int = 0
var career_total_losses: int = 0
var career_total_draws: int = 0
var career_win_rate_bp: int = 0
var queue_state: String = ""
var queue_type: String = ""
var queue_status_text: String = ""
var assignment_id: String = ""
var assignment_status_text: String = ""


func to_dict() -> Dictionary:
	return {
		"account_id": account_id,
		"profile_id": profile_id,
		"auth_mode": auth_mode,
		"session_state": session_state,
		"profile_source": profile_source,
		"last_sync_msec": last_sync_msec,
		"profile_name": profile_name,
		"default_character_id": default_character_id,
		"default_character_skin_id": default_character_skin_id,
		"default_bubble_style_id": default_bubble_style_id,
		"default_bubble_skin_id": default_bubble_skin_id,
		"last_server_host": last_server_host,
		"last_server_port": last_server_port,
		"last_room_id": last_room_id,
		"reconnect_room_id": reconnect_room_id,
		"reconnect_host": reconnect_host,
		"reconnect_port": reconnect_port,
		"reconnect_room_kind": reconnect_room_kind,
		"reconnect_room_display_name": reconnect_room_display_name,
		"reconnect_topology": reconnect_topology,
		"reconnect_match_id": reconnect_match_id,
		"reconnect_member_id": reconnect_member_id,
		"reconnect_token": reconnect_token,
		"reconnect_state": reconnect_state,
		"reconnect_resume_deadline_msec": reconnect_resume_deadline_msec,
		"preferred_map_id": preferred_map_id,
		"preferred_rule_id": preferred_rule_id,
		"preferred_mode_id": preferred_mode_id,
		"current_season_id": current_season_id,
		"current_rating": current_rating,
		"current_rank_tier": current_rank_tier,
		"career_total_matches": career_total_matches,
		"career_total_wins": career_total_wins,
		"career_total_losses": career_total_losses,
		"career_total_draws": career_total_draws,
		"career_win_rate_bp": career_win_rate_bp,
		"queue_state": queue_state,
		"queue_type": queue_type,
		"queue_status_text": queue_status_text,
		"assignment_id": assignment_id,
		"assignment_status_text": assignment_status_text,
	}
