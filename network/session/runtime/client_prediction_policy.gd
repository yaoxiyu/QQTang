class_name ClientPredictionPolicy
extends RefCounted

const MIN_INPUT_LEAD_TICKS := 3
const MAX_INPUT_LEAD_TICKS := 12
const OPENING_INPUT_LEAD_TICKS := 6

var _start_config: BattleStartConfig = null
var _prediction_controller: PredictionController = null
var _runtime_input_lead_ticks: int = 0


func configure(start_config: BattleStartConfig, prediction_controller: PredictionController) -> void:
	_start_config = start_config
	_prediction_controller = prediction_controller


func resolve_runtime_input_lead_ticks() -> int:
	var base_lead := int(_start_config.network_input_lead_ticks) if _start_config != null else MIN_INPUT_LEAD_TICKS
	if base_lead <= 0:
		base_lead = MIN_INPUT_LEAD_TICKS
	if _runtime_input_lead_ticks <= 0:
		_runtime_input_lead_ticks = clamp(base_lead, MIN_INPUT_LEAD_TICKS, MAX_INPUT_LEAD_TICKS)
	if is_dedicated_opening_lead_window():
		return max(_runtime_input_lead_ticks, OPENING_INPUT_LEAD_TICKS)
	return _runtime_input_lead_ticks


func is_dedicated_opening_lead_window() -> bool:
	if _start_config == null or _prediction_controller == null:
		return false
	if String(_start_config.topology) != "dedicated_server":
		return false
	if String(_start_config.session_mode) != "network_client":
		return false
	var opening_ticks: int = max(int(_start_config.opening_input_freeze_ticks), OPENING_INPUT_LEAD_TICKS)
	return int(_prediction_controller.authoritative_tick) < int(_start_config.start_tick) + opening_ticks


func should_suppress_place_prediction() -> bool:
	if _start_config == null:
		return false
	return String(_start_config.topology) == "dedicated_server"


func should_suppress_authority_only_entity_prediction() -> bool:
	if _start_config == null:
		return false
	return String(_start_config.topology) == "dedicated_server"


func should_compare_authority_only_entities_in_rollback() -> bool:
	return not should_suppress_authority_only_entity_prediction()


func resolve_ignored_local_player_keys_for_rollback() -> Array[String]:
	if _start_config == null:
		return []
	if String(_start_config.topology) != "dedicated_server":
		return []
	return [
		"last_place_bubble_pressed",
		"bomb_available",
	]


func reset() -> void:
	_start_config = null
	_prediction_controller = null
	_runtime_input_lead_ticks = 0
