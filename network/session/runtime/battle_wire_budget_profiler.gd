class_name BattleWireBudgetProfiler
extends RefCounted

const BattleWireBudgetContractScript = preload("res://network/session/runtime/battle_wire_budget_contract.gd")

var _last_profiles: Dictionary = {}
var _max_bytes_by_type: Dictionary = {}
var _promotion_count_by_type: Dictionary = {}


func profile_input_batch(batch: Dictionary, encoded_bytes: int) -> Dictionary:
	var frames: Array = batch.get("frames", []) if batch.get("frames", []) is Array else []
	var profile := _build_base_profile("INPUT_BATCH", encoded_bytes, BattleWireBudgetContractScript.INPUT_BATCH_WARN_BYTES)
	profile["frame_count"] = frames.size()
	profile["frames_bytes"] = var_to_bytes(frames).size()
	profile["envelope_bytes"] = max(0, encoded_bytes - int(profile["frames_bytes"]))
	_record_profile("INPUT_BATCH", profile)
	return profile


func profile_state_summary(summary: Dictionary, encoded_bytes: int) -> Dictionary:
	var profile := _build_base_profile("STATE_SUMMARY", encoded_bytes, BattleWireBudgetContractScript.STATE_SUMMARY_WARN_BYTES)
	profile["players_bytes"] = var_to_bytes(summary.get("player_summary", [])).size()
	profile["bubbles_bytes"] = var_to_bytes(summary.get("bubbles", [])).size()
	profile["items_bytes"] = var_to_bytes(summary.get("items", [])).size()
	profile["events_bytes"] = var_to_bytes(summary.get("events", [])).size()
	profile["match_state_bytes"] = var_to_bytes(summary.get("match_state", {})).size()
	profile["bubble_count"] = _section_count(summary.get("bubbles", []))
	profile["item_count"] = _section_count(summary.get("items", []))
	profile["event_count"] = _section_count(summary.get("events", []))
	_record_profile("STATE_SUMMARY", profile)
	return profile


func profile_checkpoint(checkpoint: Dictionary, encoded_bytes: int) -> Dictionary:
	var profile := _build_base_profile("CHECKPOINT", encoded_bytes, BattleWireBudgetContractScript.CHECKPOINT_RELIABLE_TARGET_BYTES)
	profile["players_bytes"] = var_to_bytes(checkpoint.get("players", [])).size()
	profile["bubbles_bytes"] = var_to_bytes(checkpoint.get("bubbles", [])).size()
	profile["items_bytes"] = var_to_bytes(checkpoint.get("items", [])).size()
	profile["match_state_bytes"] = var_to_bytes(checkpoint.get("match_state", {})).size()
	profile["mode_state_bytes"] = var_to_bytes(checkpoint.get("mode_state", {})).size()
	profile["bubble_count"] = _section_count(checkpoint.get("bubbles", []))
	profile["item_count"] = _section_count(checkpoint.get("items", []))
	_record_profile("CHECKPOINT", profile)
	return profile


func record_transport_promotion(message_type: String, encoded_bytes: int, peer_id: int) -> void:
	var key := String(message_type)
	_promotion_count_by_type[key] = int(_promotion_count_by_type.get(key, 0)) + 1
	_last_profiles["last_promotion"] = {
		"message_type": key,
		"encoded_bytes": encoded_bytes,
		"peer_id": peer_id,
	}


func build_metrics() -> Dictionary:
	return {
		"last_profiles": _last_profiles.duplicate(true),
		"max_bytes_by_type": _max_bytes_by_type.duplicate(true),
		"promotion_count_by_type": _promotion_count_by_type.duplicate(true),
	}


func reset() -> void:
	_last_profiles.clear()
	_max_bytes_by_type.clear()
	_promotion_count_by_type.clear()


func _build_base_profile(message_type: String, encoded_bytes: int, budget_bytes: int) -> Dictionary:
	return {
		"message_type": message_type,
		"encoded_bytes": encoded_bytes,
		"budget_bytes": budget_bytes,
		"budget_exceeded": encoded_bytes > budget_bytes,
		"envelope_bytes": 0,
		"frames_bytes": 0,
		"players_bytes": 0,
		"bubbles_bytes": 0,
		"items_bytes": 0,
		"events_bytes": 0,
		"match_state_bytes": 0,
		"mode_state_bytes": 0,
		"debug_bytes": 0,
		"frame_count": 0,
		"bubble_count": 0,
		"item_count": 0,
		"event_count": 0,
		"promoted_to_reliable_count": int(_promotion_count_by_type.get(message_type, 0)),
	}


func _record_profile(message_type: String, profile: Dictionary) -> void:
	var key := String(message_type)
	_last_profiles[key] = profile.duplicate(true)
	_max_bytes_by_type[key] = max(int(_max_bytes_by_type.get(key, 0)), int(profile.get("encoded_bytes", 0)))


func _section_count(section: Variant) -> int:
	if section is Array:
		return (section as Array).size()
	if section is Dictionary:
		return (section as Dictionary).size()
	return 0
