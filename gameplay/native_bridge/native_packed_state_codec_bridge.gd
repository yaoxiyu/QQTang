class_name NativePackedStateCodecBridge
extends RefCounted

const LogBattleScript = preload("res://app/logging/log_battle.gd")

const LOG_TAG := "battle.native.snapshot.codec"


func encode_snapshot_payload(snapshot: WorldSnapshot) -> PackedByteArray:
	if snapshot == null:
		return PackedByteArray()

	var payload := {
		"tick_id": snapshot.tick_id,
		"rng_state": snapshot.rng_state,
		"players": snapshot.players.duplicate(true),
		"bubbles": snapshot.bubbles.duplicate(true),
		"items": snapshot.items.duplicate(true),
		"walls": snapshot.walls.duplicate(true),
		"match_state": snapshot.match_state.duplicate(true),
		"mode_state": snapshot.mode_state.duplicate(true),
		"checksum": snapshot.checksum,
	}
	return var_to_bytes(payload)


func decode_snapshot_payload(snapshot_bytes: PackedByteArray) -> WorldSnapshot:
	if snapshot_bytes.is_empty():
		return null

	var payload_variant: Variant = bytes_to_var(snapshot_bytes)
	if not (payload_variant is Dictionary):
		LogBattleScript.warn(
			"[native_packed_state_codec_bridge] snapshot payload decode returned non-dictionary",
			"",
			0,
			LOG_TAG
		)
		return null

	var payload: Dictionary = payload_variant
	var snapshot := WorldSnapshot.new()
	snapshot.tick_id = int(payload.get("tick_id", 0))
	snapshot.rng_state = int(payload.get("rng_state", 0))
	snapshot.players = _coerce_dict_array(payload.get("players", []))
	snapshot.bubbles = _coerce_dict_array(payload.get("bubbles", []))
	snapshot.items = _coerce_dict_array(payload.get("items", []))
	snapshot.walls = _coerce_dict_array(payload.get("walls", []))
	snapshot.match_state = _coerce_dictionary(payload.get("match_state", {}))
	snapshot.mode_state = _coerce_dictionary(payload.get("mode_state", {}))
	snapshot.checksum = int(payload.get("checksum", 0))
	return snapshot


func _coerce_dict_array(raw_value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if raw_value is Array:
		for entry in raw_value:
			if entry is Dictionary:
				result.append((entry as Dictionary).duplicate(true))
	return result


func _coerce_dictionary(raw_value: Variant) -> Dictionary:
	if raw_value is Dictionary:
		return (raw_value as Dictionary).duplicate(true)
	return {}
