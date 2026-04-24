extends QQTUnitTest

const TransportMessageTypesScript = preload("res://network/transport/transport_message_types.gd")


func test_native_battle_message_codec_roundtrips_input_frame() -> void:
	var codec: Object = ClassDB.instantiate("QQTNativeBattleMessageCodec")
	assert_not_null(codec)
	assert_eq(String(codec.call("get_kernel_version")), "phase32_sync_kernel_v1")
	var original := {
		"message_type": TransportMessageTypesScript.INPUT_FRAME,
		"tick": 12,
		"frame": {"peer_id": 2, "tick_id": 12, "move_x": 1},
	}
	var payload: PackedByteArray = codec.call("encode_message", original)
	assert_true(bool(codec.call("is_native_payload", payload)))
	var decoded: Dictionary = codec.call("decode_message", payload)
	assert_eq(String(decoded.get("message_type", "")), TransportMessageTypesScript.INPUT_FRAME)
	assert_eq(int(decoded.get("tick", 0)), 12)


func test_native_battle_message_codec_roundtrips_ack_summary_checkpoint() -> void:
	var codec: Object = ClassDB.instantiate("QQTNativeBattleMessageCodec")
	for message in [
		{"message_type": TransportMessageTypesScript.INPUT_ACK, "peer_id": 2, "ack_tick": 7},
		{"message_type": TransportMessageTypesScript.STATE_SUMMARY, "tick": 8, "player_summary": []},
		{"message_type": TransportMessageTypesScript.CHECKPOINT, "tick": 10, "players": [], "bubbles": [], "items": []},
	]:
		var payload: PackedByteArray = codec.call("encode_message", message)
		var decoded: Dictionary = codec.call("decode_message", payload)
		assert_eq(String(decoded.get("message_type", "")), String(message.get("message_type", "")))


func test_native_battle_message_codec_malformed_payload_returns_empty() -> void:
	var codec: Object = ClassDB.instantiate("QQTNativeBattleMessageCodec")
	var malformed := PackedByteArray([81, 81, 84, 83, 0, 1, 0, 0, 0, 0, 0, 10])
	var decoded: Dictionary = codec.call("decode_message", malformed)
	var metrics: Dictionary = codec.call("get_metrics")
	assert_true(decoded.is_empty())
	assert_eq(int(metrics.get("malformed_count", 0)), 1)
