extends "res://tests/gut/base/qqt_unit_test.gd"

const TransportMessageCodecScript = preload("res://network/transport/transport_message_codec.gd")
const TransportMessageTypesScript = preload("res://network/transport/transport_message_types.gd")


func test_main() -> void:
	var ok := true
	ok = _test_encode_decode_roundtrip() and ok
	ok = _test_dictionary_decode_normalizes_message_type_keys() and ok
	ok = _test_state_summary_primitive_positions_survive_roundtrip() and ok


func _test_encode_decode_roundtrip() -> bool:
	var original := {
		"msg_type": TransportMessageTypesScript.PING,
		"protocol_version": 7,
		"tick": 42,
		"match_id": "codec_transport_match",
	}
	var payload := TransportMessageCodecScript.encode_message(original)
	var decoded := TransportMessageCodecScript.decode_message(payload)
	var prefix := "transport_codec_test"
	var ok := true
	ok = qqt_check(payload.size() > 0, "encode_message should produce bytes", prefix) and ok
	ok = qqt_check(String(decoded.get("message_type", "")) == TransportMessageTypesScript.PING, "decoded message_type should be preserved", prefix) and ok
	ok = qqt_check(String(decoded.get("msg_type", "")) == TransportMessageTypesScript.PING, "decoded legacy msg_type should be preserved", prefix) and ok
	ok = qqt_check(int(decoded.get("protocol_version", 0)) == 7, "protocol_version should survive roundtrip", prefix) and ok
	ok = qqt_check(int(decoded.get("tick", 0)) == 42, "tick should survive roundtrip", prefix) and ok
	ok = qqt_check(String(decoded.get("match_id", "")) == "codec_transport_match", "match_id should survive roundtrip", prefix) and ok
	return ok


func _test_dictionary_decode_normalizes_message_type_keys() -> bool:
	var normalized := TransportMessageCodecScript.decode_message({
		"message_type": TransportMessageTypesScript.PING,
		"protocol_version": 3,
		"tick": 8,
	})
	var prefix := "transport_codec_test"
	var ok := true
	ok = qqt_check(String(normalized.get("message_type", "")) == TransportMessageTypesScript.PING, "decode_message should keep message_type", prefix) and ok
	ok = qqt_check(String(normalized.get("msg_type", "")) == TransportMessageTypesScript.PING, "decode_message should backfill msg_type", prefix) and ok
	ok = qqt_check(int(normalized.get("tick", 0)) == 8, "decode_message should keep tick from dictionary input", prefix) and ok
	return ok


func _test_state_summary_primitive_positions_survive_roundtrip() -> bool:
	var original := {
		"message_type": TransportMessageTypesScript.STATE_SUMMARY,
		"tick": 12,
		"player_summary": [{
			"entity_id": 101,
			"player_slot": 1,
			"grid_cell_x": 7,
			"grid_cell_y": 3,
			"move_progress_x": 11,
			"move_progress_y": -5,
			"move_dir_x": 1,
			"move_dir_y": 0,
			"facing": 3,
			"move_state": 1,
		}],
	}
	var payload := TransportMessageCodecScript.encode_message(original)
	var decoded := TransportMessageCodecScript.decode_message(payload)
	var summary: Array = decoded.get("player_summary", [])
	var first: Dictionary = summary[0] if not summary.is_empty() and summary[0] is Dictionary else {}
	var prefix := "transport_codec_test"
	var ok := true
	ok = qqt_check(int(first.get("grid_cell_x", -1)) == 7, "primitive grid_cell_x should survive roundtrip", prefix) and ok
	ok = qqt_check(int(first.get("grid_cell_y", -1)) == 3, "primitive grid_cell_y should survive roundtrip", prefix) and ok
	ok = qqt_check(int(first.get("move_progress_x", 999)) == 11, "primitive move_progress_x should survive roundtrip", prefix) and ok
	ok = qqt_check(int(first.get("move_progress_y", 999)) == -5, "primitive move_progress_y should survive roundtrip", prefix) and ok
	ok = qqt_check(int(first.get("move_dir_x", 999)) == 1, "primitive move_dir_x should survive roundtrip", prefix) and ok
	ok = qqt_check(int(first.get("move_dir_y", 999)) == 0, "primitive move_dir_y should survive roundtrip", prefix) and ok
	return ok
