class_name SettlementController
extends Control

const AppRuntimeRootScript = preload("res://app/flow/app_runtime_root.gd")
signal settlement_shown(result: BattleResult)
signal settlement_hidden()
signal return_to_room_requested()
signal rematch_requested()
signal input_frozen(frozen: bool)

@export var result_label_path: NodePath = ^"ResultLabel"
@export var detail_label_path: NodePath = ^"DetailLabel"
@export var map_summary_label_path: NodePath = ^"MapSummaryLabel"
@export var rule_summary_label_path: NodePath = ^"RuleSummaryLabel"
@export var finish_reason_label_path: NodePath = ^"FinishReasonLabel"

var result_label: Label = null
var detail_label: Label = null
var map_summary_label: Label = null
var rule_summary_label: Label = null
var finish_reason_label: Label = null
var current_result: BattleResult = null
var input_locked: bool = false


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

	visible = false
	_refresh_text()


func show_result(result: BattleResult) -> void:
	if result == null:
		return

	current_result = result.duplicate_deep()
	_set_input_locked(true)
	_refresh_text()
	visible = true
	settlement_shown.emit(current_result)


func hide_result() -> void:
	current_result = null
	_set_input_locked(false)
	visible = false
	_refresh_text()
	settlement_hidden.emit()


func request_return_to_room() -> void:
	return_to_room_requested.emit()


func request_rematch() -> void:
	rematch_requested.emit()


func reset_settlement() -> void:
	hide_result()


func debug_dump_settlement_state() -> Dictionary:
	return {
		"visible": visible,
		"input_locked": input_locked,
		"result_text": result_label.text if result_label != null else "",
		"detail_text": detail_label.text if detail_label != null else "",
		"map_summary_text": map_summary_label.text if map_summary_label != null else "",
		"rule_summary_text": rule_summary_label.text if rule_summary_label != null else "",
		"finish_reason_text": finish_reason_label.text if finish_reason_label != null else "",
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


func _build_title_text() -> String:
	if current_result == null:
		return ""
	if current_result.is_local_victory():
		return "Victory"
	if not current_result.winner_peer_ids.is_empty():
		return "Defeat"
	if _is_draw_result(current_result):
		return "Draw"
	return "Match Ended"


func _build_detail_text() -> String:
	if current_result == null:
		return ""

	var lines: Array[String] = [
		"FinishReason: %s" % current_result.finish_reason,
		"FinishTick: %d" % current_result.finish_tick,
	]

	if not current_result.winner_peer_ids.is_empty():
		lines.append("Winners: %s" % str(current_result.winner_peer_ids))
	if not current_result.eliminated_order.is_empty():
		lines.append("Eliminated: %s" % str(current_result.eliminated_order))

	return "\n".join(lines)


func _build_map_summary_text() -> String:
	var manifest := _resolve_current_manifest()
	var map_manifest: Dictionary = manifest.get("map", {})
	if map_manifest.is_empty():
		return ""
	var display_name := String(map_manifest.get("display_name", map_manifest.get("map_id", "")))
	var width := int(map_manifest.get("width", 0))
	var height := int(map_manifest.get("height", 0))
	return "Map: %s (%dx%d)" % [display_name, width, height]


func _build_rule_summary_text() -> String:
	var manifest := _resolve_current_manifest()
	var rule_manifest: Dictionary = manifest.get("rule", {})
	var ui_summary: Dictionary = manifest.get("ui_summary", {})
	if rule_manifest.is_empty():
		return ""
	var display_name := String(rule_manifest.get("display_name", rule_manifest.get("rule_set_id", "")))
	var round_time_sec := int(rule_manifest.get("round_time_sec", 0))
	var item_brief := String(ui_summary.get("item_brief", ""))
	if not item_brief.is_empty():
		return "Rule: %s (%ds)\n%s" % [display_name, round_time_sec, item_brief]
	return "Rule: %s (%ds)" % [display_name, round_time_sec]


func _build_finish_reason_text() -> String:
	if current_result == null:
		return ""
	return "Reason: %s" % _map_finish_reason_text(current_result.finish_reason)


func _resolve_current_start_config():
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
	var tree := get_tree()
	if tree == null:
		return {}
	if not tree.root.has_node(AppRuntimeRootScript.ROOT_NODE_NAME) and not tree.root.has_node(AppRuntimeRootScript.LEGACY_ROOT_NODE_NAME):
		return {}
	var app_runtime = AppRuntimeRootScript.ensure_in_tree(tree)
	if app_runtime == null:
		return {}
	return app_runtime.current_battle_content_manifest.duplicate(true)


func _map_finish_reason_text(finish_reason: String) -> String:
	match finish_reason:
		"last_survivor", "last_alive":
			return "最后生存者获胜"
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
	if result.finish_reason == "time_up":
		return true
	return result.finish_reason == "last_survivor" and result.winner_peer_ids.is_empty()
