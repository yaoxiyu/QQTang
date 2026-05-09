class_name SettlementController
extends Control

const AppRuntimeRootScript = preload("res://app/flow/app_runtime_root.gd")
const LogFrontScript = preload("res://app/logging/log_front.gd")
const ONLINE_LOG_PREFIX := "[ONLINE]"
signal settlement_shown(result: BattleResult)
signal settlement_hidden()
signal return_to_room_requested()
signal return_to_source_room_requested()
signal rematch_requested()
signal input_frozen(frozen: bool)

@export var result_label_path: NodePath = ^"ResultLabel"
@export var detail_label_path: NodePath = ^"DetailLabel"
@export var map_summary_label_path: NodePath = ^"MapSummaryLabel"
@export var rule_summary_label_path: NodePath = ^"RuleSummaryLabel"
@export var finish_reason_label_path: NodePath = ^"FinishReasonLabel"
@export var mode_summary_label_path: NodePath = ^"ModeSummaryLabel"
@export var character_summary_label_path: NodePath = ^"CharacterSummaryLabel"
@export var bubble_summary_label_path: NodePath = ^"BubbleSummaryLabel"
@export var score_summary_label_path: NodePath = ^"ScoreSummaryLabel"
@export var team_outcome_label_path: NodePath = ^"TeamOutcomeLabel"
@export var server_sync_label_path: NodePath = ^"ServerSyncLabel"
@export var rating_delta_label_path: NodePath = ^"RatingDeltaLabel"
@export var season_point_delta_label_path: NodePath = ^"SeasonPointDeltaLabel"
@export var reward_summary_label_path: NodePath = ^"RewardSummaryLabel"
@export var career_summary_label_path: NodePath = ^"CareerSummaryLabel"
@export var return_button_path: NodePath = ^"ActionRow/ReturnToRoomButton"
@export var rematch_button_path: NodePath = ^"ActionRow/RematchButton"

var result_label: Label = null
var detail_label: Label = null
var map_summary_label: Label = null
var rule_summary_label: Label = null
var finish_reason_label: Label = null
var mode_summary_label: Label = null
var character_summary_label: Label = null
var bubble_summary_label: Label = null
var score_summary_label: Label = null
var team_outcome_label: Label = null
var server_sync_label: Label = null
var rating_delta_label: Label = null
var season_point_delta_label: Label = null
var reward_summary_label: Label = null
var career_summary_label: Label = null
var return_button: Button = null
var rematch_button: Button = null
var current_result: BattleResult = null
var input_locked: bool = false
var server_sync_state: String = "pending"
var rating_delta: int = 0
var rating_after: int = 0
var season_point_delta: int = 0
var reward_summary_text: String = ""
var career_summary_text: String = ""
var return_to_lobby_mode: bool = false


func _ready() -> void:
	if has_node(result_label_path):
		result_label = get_node(result_label_path)
	if has_node(detail_label_path):
		detail_label = get_node(detail_label_path)
	if has_node(map_summary_label_path):
		map_summary_label = get_node(map_summary_label_path)
	if has_node(rule_summary_label_path):
		rule_summary_label = get_node(rule_summary_label_path)
	if has_node(finish_reason_label_path):
		finish_reason_label = get_node(finish_reason_label_path)
	if has_node(mode_summary_label_path):
		mode_summary_label = get_node(mode_summary_label_path)
	if has_node(character_summary_label_path):
		character_summary_label = get_node(character_summary_label_path)
	if has_node(bubble_summary_label_path):
		bubble_summary_label = get_node(bubble_summary_label_path)
	if has_node(score_summary_label_path):
		score_summary_label = get_node(score_summary_label_path)
	if has_node(team_outcome_label_path):
		team_outcome_label = get_node(team_outcome_label_path)
	if has_node(server_sync_label_path):
		server_sync_label = get_node(server_sync_label_path)
	if has_node(rating_delta_label_path):
		rating_delta_label = get_node(rating_delta_label_path)
	if has_node(season_point_delta_label_path):
		season_point_delta_label = get_node(season_point_delta_label_path)
	if has_node(reward_summary_label_path):
		reward_summary_label = get_node(reward_summary_label_path)
	if has_node(career_summary_label_path):
		career_summary_label = get_node(career_summary_label_path)
	if has_node(return_button_path):
		return_button = get_node(return_button_path)
	if has_node(rematch_button_path):
		rematch_button = get_node(rematch_button_path)

	if return_button != null and not return_button.pressed.is_connected(request_return_to_room):
		return_button.pressed.connect(request_return_to_room)
	if rematch_button != null and not rematch_button.pressed.is_connected(request_rematch):
		rematch_button.pressed.connect(request_rematch)

	visible = false
	_refresh_text()


func show_result(result: BattleResult) -> void:
	if result == null:
		return

	current_result = result.duplicate_deep()
	server_sync_state = "pending"
	rating_delta = 0
	rating_after = 0
	season_point_delta = 0
	reward_summary_text = ""
	career_summary_text = ""
	_set_input_locked(true)
	_refresh_text()
	visible = true
	_log_online_settlement("show_result", debug_dump_settlement_state())
	settlement_shown.emit(current_result)


func hide_result() -> void:
	current_result = null
	_set_input_locked(false)
	visible = false
	_refresh_text()
	_log_online_settlement("hide_result", debug_dump_settlement_state())
	settlement_hidden.emit()


func request_return_to_room() -> void:
	return_to_room_requested.emit()


## LegacyMigration: Default post-battle action — return to source room instead of lobby.
func request_return_to_source_room() -> void:
	return_to_source_room_requested.emit()


func request_rematch() -> void:
	rematch_requested.emit()


func reset_settlement() -> void:
	hide_result()


func apply_server_summary(summary: Dictionary) -> void:
	var resolved_summary: Dictionary = summary.duplicate(true) if summary != null else {}
	server_sync_state = String(resolved_summary.get("server_sync_state", server_sync_state))
	rating_delta = int(resolved_summary.get("rating_delta", rating_delta))
	rating_after = int(resolved_summary.get("rating_after", rating_after))
	season_point_delta = int(resolved_summary.get("season_point_delta", season_point_delta))
	reward_summary_text = String(resolved_summary.get("reward_summary_text", reward_summary_text))
	career_summary_text = String(resolved_summary.get("career_summary_text", career_summary_text))
	_refresh_text()
	_log_online_settlement("apply_server_summary", debug_dump_settlement_state())


func set_return_button_mode_lobby() -> void:
	return_to_lobby_mode = true
	if return_button != null:
		return_button.text = "Back To Lobby"
	if rematch_button != null:
		rematch_button.disabled = true
		rematch_button.visible = false
	_log_online_settlement("set_return_button_mode_lobby", debug_dump_settlement_state())


func set_return_button_mode_room() -> void:
	return_to_lobby_mode = false
	if return_button != null:
		return_button.text = "返回房间"
		# LegacyMigration: reconnect return button to source room flow
		if return_button.pressed.is_connected(request_return_to_room):
			return_button.pressed.disconnect(request_return_to_room)
		if not return_button.pressed.is_connected(request_return_to_source_room):
			return_button.pressed.connect(request_return_to_source_room)
	if rematch_button != null:
		rematch_button.disabled = false
		rematch_button.visible = true
	_log_online_settlement("set_return_button_mode_room", debug_dump_settlement_state())


func debug_dump_settlement_state() -> Dictionary:
	return {
		"visible": visible,
		"input_locked": input_locked,
		"result_text": result_label.text if result_label != null else "",
		"detail_text": detail_label.text if detail_label != null else "",
		"map_summary_text": map_summary_label.text if map_summary_label != null else "",
		"rule_summary_text": rule_summary_label.text if rule_summary_label != null else "",
		"finish_reason_text": finish_reason_label.text if finish_reason_label != null else "",
		"mode_summary_text": mode_summary_label.text if mode_summary_label != null else "",
		"character_summary_text": character_summary_label.text if character_summary_label != null else "",
		"bubble_summary_text": bubble_summary_label.text if bubble_summary_label != null else "",
		"score_summary_text": score_summary_label.text if score_summary_label != null else "",
		"team_outcome_text": team_outcome_label.text if team_outcome_label != null else "",
		"server_sync_text": server_sync_label.text if server_sync_label != null else "",
		"rating_delta_text": rating_delta_label.text if rating_delta_label != null else "",
		"season_point_delta_text": season_point_delta_label.text if season_point_delta_label != null else "",
		"reward_summary_text": reward_summary_label.text if reward_summary_label != null else "",
		"career_summary_text": career_summary_label.text if career_summary_label != null else "",
		"return_to_lobby_mode": return_to_lobby_mode,
	}


func _set_input_locked(frozen: bool) -> void:
	input_locked = frozen
	input_frozen.emit(input_locked)


func _refresh_text() -> void:
	if result_label != null:
		result_label.text = _build_title_text()
	if detail_label != null:
		detail_label.text = _build_detail_text()
	if map_summary_label != null:
		map_summary_label.text = _build_map_summary_text()
	if rule_summary_label != null:
		rule_summary_label.text = _build_rule_summary_text()
	if finish_reason_label != null:
		finish_reason_label.text = _build_finish_reason_text()
	if mode_summary_label != null:
		mode_summary_label.text = _build_mode_summary_text()
	if character_summary_label != null:
		character_summary_label.text = _build_character_summary_text()
	if bubble_summary_label != null:
		bubble_summary_label.text = _build_bubble_summary_text()
	if score_summary_label != null:
		score_summary_label.text = _build_score_summary_text()
	if team_outcome_label != null:
		team_outcome_label.text = _build_team_outcome_text()
	if server_sync_label != null:
		server_sync_label.text = _build_server_sync_text()
	if rating_delta_label != null:
		rating_delta_label.text = _build_rating_delta_text()
	if season_point_delta_label != null:
		season_point_delta_label.text = _build_season_point_delta_text()
	if reward_summary_label != null:
		reward_summary_label.text = _build_reward_summary_text()
	if career_summary_label != null:
		career_summary_label.text = _build_career_summary_text()


func _build_title_text() -> String:
	if current_result == null:
		return ""
	if current_result.local_outcome == "victory":
		return "Victory"
	if current_result.local_outcome == "defeat":
		return "Defeat"
	if current_result.local_outcome == "draw":
		return "Draw"
	if current_result.is_local_victory():
		return "Victory"
	if _is_draw_result(current_result):
		return "Draw"
	if not current_result.winner_team_ids.is_empty() or not current_result.winner_peer_ids.is_empty():
		return "Defeat"
	return "Match Ended"


func _build_detail_text() -> String:
	if current_result == null:
		return ""

	var lines: Array[String] = [
		"FinishReason: %s" % current_result.finish_reason,
		"FinishTick: %d" % current_result.finish_tick,
	]

	if current_result.local_team_id >= 1:
		lines.append("LocalTeam: Team %d" % current_result.local_team_id)
	if not current_result.winner_team_ids.is_empty():
		lines.append("WinnerTeams: %s" % str(current_result.winner_team_ids))
	if not current_result.winner_peer_ids.is_empty():
		lines.append("Winners: %s" % str(current_result.winner_peer_ids))
	if not current_result.eliminated_order.is_empty():
		lines.append("Eliminated: %s" % str(current_result.eliminated_order))
	if not current_result.score_policy.is_empty():
		lines.append("ScorePolicy: %s" % current_result.score_policy)

	return "\n".join(lines)


func _build_map_summary_text() -> String:
	var manifest := _resolve_current_manifest()
	var ui_summary: Dictionary = manifest.get("ui_summary", {})
	var map_manifest: Dictionary = manifest.get("map", {})
	if map_manifest.is_empty():
		return ""
	var display_name := String(ui_summary.get("map_display_name", map_manifest.get("display_name", map_manifest.get("map_id", ""))))
	var map_brief := String(ui_summary.get("map_brief", map_manifest.get("brief", "")))
	if not map_brief.is_empty():
		return "地图: %s\n%s" % [display_name, map_brief]
	return "地图: %s" % display_name


func _build_rule_summary_text() -> String:
	var manifest := _resolve_current_manifest()
	var rule_manifest: Dictionary = manifest.get("rule", {})
	var ui_summary: Dictionary = manifest.get("ui_summary", {})
	if rule_manifest.is_empty():
		return ""
	var display_name := String(ui_summary.get("rule_display_name", rule_manifest.get("display_name", rule_manifest.get("rule_set_id", ""))))
	var rule_brief := String(ui_summary.get("rule_brief", rule_manifest.get("brief", "")))
	var item_brief := String(ui_summary.get("item_brief", ""))
	var detail_lines: PackedStringArray = PackedStringArray()
	if not rule_brief.is_empty():
		detail_lines.append(rule_brief)
	if not item_brief.is_empty():
		detail_lines.append(item_brief)
	if not detail_lines.is_empty():
		return "规则: %s\n%s" % [display_name, "\n".join(detail_lines)]
	return "规则: %s" % display_name


func _build_finish_reason_text() -> String:
	if current_result == null:
		return ""
	return "原因: %s" % _map_finish_reason_text(current_result.finish_reason)


func _build_mode_summary_text() -> String:
	var manifest := _resolve_current_manifest()
	var ui_summary: Dictionary = manifest.get("ui_summary", {})
	var mode_manifest: Dictionary = manifest.get("mode", {})
	var display_name := String(ui_summary.get("mode_display_name", mode_manifest.get("display_name", mode_manifest.get("mode_id", ""))))
	if display_name.is_empty():
		return ""
	return "模式: %s" % display_name


func _build_character_summary_text() -> String:
	var manifest := _resolve_current_manifest()
	var local_peer_id := _resolve_local_peer_id()
	for entry in manifest.get("characters", []):
		if int(entry.get("peer_id", -1)) == local_peer_id:
			var display_name := String(entry.get("display_name", entry.get("character_id", "")))
			return "角色: %s" % display_name
	return ""


func _build_bubble_summary_text() -> String:
	var manifest := _resolve_current_manifest()
	var local_peer_id := _resolve_local_peer_id()
	for entry in manifest.get("bubbles", []):
		if int(entry.get("peer_id", -1)) == local_peer_id:
			var display_name := String(entry.get("display_name", entry.get("bubble_style_id", "")))
			return "泡泡: %s" % display_name
	return ""


func _build_score_summary_text() -> String:
	if current_result == null:
		return ""
	if current_result.team_scores.is_empty():
		return ""

	var team_ids: Array[int] = []
	for team_id_variant in current_result.team_scores.keys():
		team_ids.append(int(team_id_variant))
	team_ids.sort()

	var lines: Array[String] = ["队伍积分:"]
	for team_id in team_ids:
		lines.append("Team %d : %d" % [team_id, int(current_result.team_scores.get(str(team_id), current_result.team_scores.get(team_id, 0)))])
	return "\n".join(lines)


func _build_team_outcome_text() -> String:
	if current_result == null:
		return ""

	var lines: Array[String] = []
	if current_result.local_team_id >= 1:
		lines.append("你所在队伍: Team %d" % current_result.local_team_id)
	if not current_result.local_outcome.is_empty():
		lines.append("结果: %s" % _map_outcome_text(current_result.local_outcome))
	return "\n".join(lines)


func _build_server_sync_text() -> String:
	return "Server Sync: %s" % _map_server_sync_text(server_sync_state)


func _build_rating_delta_text() -> String:
	if server_sync_state == "pending":
		return "Rating: -"
	if rating_after > 0:
		return "Rating: %s -> %d" % [_format_signed_number(rating_delta), rating_after]
	return "Rating: %s" % _format_signed_number(rating_delta)


func _build_season_point_delta_text() -> String:
	if server_sync_state == "pending":
		return "Season Point: -"
	return "Season Point: %s" % _format_signed_number(season_point_delta)


func _build_reward_summary_text() -> String:
	if reward_summary_text.strip_edges().is_empty():
		return "Reward: -"
	return "Reward: %s" % reward_summary_text


func _build_career_summary_text() -> String:
	if career_summary_text.strip_edges().is_empty():
		return "Career: -"
	return "Career: %s" % career_summary_text


func _resolve_current_start_config():
	if not is_inside_tree():
		return null
	var tree := get_tree()
	if tree == null:
		return null
	if not tree.root.has_node(AppRuntimeRootScript.ROOT_NODE_NAME) and not tree.root.has_node(AppRuntimeRootScript.LEGACY_ROOT_NODE_NAME):
		return null
	var app_runtime = AppRuntimeRootScript.ensure_in_tree(tree)
	if app_runtime == null:
		return null
	return app_runtime.current_start_config


func _resolve_current_manifest() -> Dictionary:
	if not is_inside_tree():
		return {}
	var tree := get_tree()
	if tree == null:
		return {}
	if not tree.root.has_node(AppRuntimeRootScript.ROOT_NODE_NAME) and not tree.root.has_node(AppRuntimeRootScript.LEGACY_ROOT_NODE_NAME):
		return {}
	var app_runtime = AppRuntimeRootScript.ensure_in_tree(tree)
	if app_runtime == null:
		return {}
	return app_runtime.current_battle_content_manifest.duplicate(true)


func _resolve_local_peer_id() -> int:
	var start_config = _resolve_current_start_config()
	if start_config == null:
		return -1
	var controlled_peer_id := int(start_config.controlled_peer_id)
	if controlled_peer_id > 0:
		return controlled_peer_id
	return int(start_config.local_peer_id)


func _map_finish_reason_text(finish_reason: String) -> String:
	match finish_reason:
		"last_survivor", "last_alive":
			return "最后生存者获胜"
		"team_eliminated":
			return "队伍淘汰"
		"time_up":
			return "时间结束"
		"peer_disconnected":
			return "对局因断线中止"
		"force_end":
			return "对局被强制结束"
		_:
			return finish_reason


func _is_draw_result(result: BattleResult) -> bool:
	if result == null:
		return false
	if result.local_outcome == "draw":
		return true
	if result.finish_reason == "time_up":
		return result.winner_team_ids.is_empty() and result.winner_peer_ids.is_empty()
	return (result.finish_reason == "last_survivor" or result.finish_reason == "team_eliminated") and result.winner_peer_ids.is_empty() and result.winner_team_ids.is_empty()


func _map_outcome_text(local_outcome: String) -> String:
	match local_outcome:
		"victory":
			return "Victory"
		"defeat":
			return "Defeat"
		"draw":
			return "Draw"
		_:
			return local_outcome


func _map_server_sync_text(state: String) -> String:
	match state.strip_edges().to_lower():
		"ok", "synced", "success", "completed", "committed":
			return "Synced"
		"failed", "error":
			return "Failed"
		"conflict":
			return "Conflict"
		"pending", "":
			return "Pending"
		_:
			return state


func _format_signed_number(value: int) -> String:
	if value > 0:
		return "+%d" % value
	return "%d" % value


func _log_online_settlement(event_name: String, payload: Dictionary) -> void:
	LogFrontScript.debug("%s[settlement_controller] %s %s" % [ONLINE_LOG_PREFIX, event_name, JSON.stringify(payload)], "", 0, "front.settlement.controller")
