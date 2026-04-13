class_name SettlementSummaryState
extends RefCounted

const SELF_SCRIPT = preload("res://app/front/settlement/settlement_summary_state.gd")

var ok: bool = false
var error_code: String = ""
var user_message: String = ""
var match_id: String = ""
var profile_id: String = ""
var server_sync_state: String = ""
var outcome: String = ""
var rating_before: int = 0
var rating_delta: int = 0
var rating_after: int = 0
var rank_tier_after: String = ""
var season_point_delta: int = 0
var career_xp_delta: int = 0
var gold_delta: int = 0
var reward_summary: Array = []
var career_summary: Dictionary = {}


static func from_response(data: Dictionary) -> SettlementSummaryState:
	var state := SELF_SCRIPT.new()
	state.ok = bool(data.get("ok", false))
	state.error_code = String(data.get("error_code", ""))
	state.user_message = String(data.get("user_message", data.get("message", "")))
	state.match_id = String(data.get("match_id", ""))
	state.profile_id = String(data.get("profile_id", ""))
	state.server_sync_state = String(data.get("server_sync_state", ""))
	state.outcome = String(data.get("outcome", ""))
	state.rating_before = int(data.get("rating_before", 0))
	state.rating_delta = int(data.get("rating_delta", 0))
	state.rating_after = int(data.get("rating_after", 0))
	state.rank_tier_after = String(data.get("rank_tier_after", ""))
	state.season_point_delta = int(data.get("season_point_delta", 0))
	state.career_xp_delta = int(data.get("career_xp_delta", 0))
	state.gold_delta = int(data.get("gold_delta", 0))
	state.reward_summary = data.get("reward_summary", [])
	state.career_summary = data.get("career_summary", {})
	return state


func to_popup_summary() -> Dictionary:
	var reward_text_parts: Array[String] = []
	for item in reward_summary:
		if item is Dictionary:
			reward_text_parts.append("%s %d" % [String(item.get("reward_type", "")), int(item.get("delta", 0))])
	var career_text := "Matches %d | W %d L %d D %d" % [
		int(career_summary.get("career_total_matches", 0)),
		int(career_summary.get("career_total_wins", 0)),
		int(career_summary.get("career_total_losses", 0)),
		int(career_summary.get("career_total_draws", 0)),
	]
	return {
		"server_sync_state": server_sync_state,
		"rating_delta": rating_delta,
		"rating_after": rating_after,
		"season_point_delta": season_point_delta,
		"reward_summary_text": ", ".join(reward_text_parts),
		"career_summary_text": career_text,
	}
