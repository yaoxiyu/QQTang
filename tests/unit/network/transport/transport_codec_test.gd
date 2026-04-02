extends Node

const TestAssert = preload("res://tests/helpers/test_assert.gd")
const TransportMessageCodecScript = preload("res://network/transport/transport_message_codec.gd")
const TransportMessageTypesScript = preload("res://network/transport/transport_message_types.gd")


func _ready() -> void:
	var ok := true
	ok = _test_encode_decode_roundtrip() and ok
	ok = _test_dictionary_decode_normalizes_message_type_keys() and ok
	if ok:
		print("transport_codec_test: PASS")


func _test_encode_decode_roundtrip() -> bool:
	var original := {
		"msg_type": TransportMessageTypesScript.INPUT_FRAME,
		"protocol_version": 7,
		"tick": 42,
		"match_id": "codec_transport_match",
		"frame": {
			"peer_id": 2,
			"tick_id": 42,
			"move_x": 1,
			"move_y": 0,
		},
	}
	var payload := TransportMessageCodecScript.encode_message(original)
	var decoded := TransportMessageCodecScript.decode_message(payload)
	var prefix := "transport_codec_test"
	var ok := true
	ok = TestAssert.is_true(payload.size() > 0, "encode_message should produce bytes", prefix) and ok
	ok = TestAssert.is_true(String(decoded.get("message_type", "")) == TransportMessageTypesScript.INPUT_FRAME, "decoded message_type should be preserved", prefix) and ok
	ok = TestAssert.is_true(String(decoded.get("msg_type", "")) == TransportMessageTypesScript.INPUT_FRAME, "decoded legacy msg_type should be preserved", prefix) and ok
	ok = TestAssert.is_true(int(decoded.get("protocol_version", 0)) == 7, "protocol_version should survive roundtrip", prefix) and ok
	ok = TestAssert.is_true(int(decoded.get("tick", 0)) == 42, "tick should survive roundtrip", prefix) and ok
	ok = TestAssert.is_true(String(decoded.get("match_id", "")) == "codec_transport_match", "match_id should survive roundtrip", prefix) and ok
	return ok


func _test_dictionary_decode_normalizes_message_type_keys() -> bool:
	var normalized := TransportMessageCodecScript.decode_message({
		"message_type": TransportMessageTypesScript.STATE_SUMMARY,
		"protocol_version": 3,
		"tick": 8,
	})
	var prefix := "transport_codec_test"
	var ok := true
	ok = TestAssert.is_true(String(normalized.get("message_type", "")) == TransportMessageTypesScript.STATE_SUMMARY, "decode_message should keep message_type", prefix) and ok
	ok = TestAssert.is_true(String(normalized.get("msg_type", "")) == TransportMessageTypesScript.STATE_SUMMARY, "decode_message should backfill msg_type", prefix) and ok
	ok = TestAssert.is_true(int(normalized.get("tick", 0)) == 8, "decode_message should keep tick from dictionary input", prefix) and ok
	return ok
