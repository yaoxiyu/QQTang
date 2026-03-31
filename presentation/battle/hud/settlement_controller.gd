class_name SettlementController
extends Control

signal settlement_shown(result: BattleResult)
signal settlement_hidden()
signal return_to_room_requested()
signal rematch_requested()
signal input_frozen(frozen: bool)

@export var result_label_path: NodePath = ^"ResultLabel"
@export var detail_label_path: NodePath = ^"DetailLabel"

var result_label: Label = null
var detail_label: Label = null
var current_result: BattleResult = null
var input_locked: bool = false


func _ready() -> void:
	if has_node(result_label_path):
		result_label = get_node(result_label_path)
	if has_node(detail_label_path):
		detail_label = get_node(detail_label_path)

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
	}


func _set_input_locked(frozen: bool) -> void:
	input_locked = frozen
	input_frozen.emit(input_locked)


func _refresh_text() -> void:
	if result_label != null:
		result_label.text = _build_title_text()
	if detail_label != null:
		detail_label.text = _build_detail_text()


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


func _is_draw_result(result: BattleResult) -> bool:
	if result == null:
		return false
	if result.finish_reason == "time_up":
		return true
	return result.finish_reason == "last_survivor" and result.winner_peer_ids.is_empty()
