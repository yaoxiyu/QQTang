class_name CareerSummaryState
extends RefCounted

const SELF_SCRIPT = preload("res://app/front/career/career_summary_state.gd")

var ok: bool = false
var error_code: String = ""
var user_message: String = ""
var summary_state: String = ""
var current_season_id: String = ""
var current_rating: int = 1000
var current_rank_tier: String = "bronze"
var career_total_matches: int = 0
var career_total_wins: int = 0
var career_total_losses: int = 0
var career_total_draws: int = 0
var career_win_rate_bp: int = 0
var last_match_id: String = ""
var last_match_outcome: String = ""
var last_match_finished_at = null


static func from_response(data: Dictionary) -> CareerSummaryState:
	var state := SELF_SCRIPT.new()
	state.ok = bool(data.get("ok", false))
	state.error_code = String(data.get("error_code", ""))
	state.user_message = String(data.get("user_message", data.get("message", "")))
	state.summary_state = String(data.get("summary_state", ""))
	state.current_season_id = String(data.get("current_season_id", ""))
	state.current_rating = int(data.get("current_rating", 1000))
	state.current_rank_tier = String(data.get("current_rank_tier", "bronze"))
	state.career_total_matches = int(data.get("career_total_matches", 0))
	state.career_total_wins = int(data.get("career_total_wins", 0))
	state.career_total_losses = int(data.get("career_total_losses", 0))
	state.career_total_draws = int(data.get("career_total_draws", 0))
	state.career_win_rate_bp = int(data.get("career_win_rate_bp", 0))
	state.last_match_id = String(data.get("last_match_id", ""))
	state.last_match_outcome = String(data.get("last_match_outcome", ""))
	state.last_match_finished_at = data.get("last_match_finished_at", null)
	return state
