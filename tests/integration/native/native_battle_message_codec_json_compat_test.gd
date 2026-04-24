extends QQTIntegrationTest

const TransportMessageCodecScript = preload("res://network/transport/transport_message_codec.gd")
const TransportMessageTypesScript = preload("res://network/transport/transport_message_types.gd")
const NativeFeatureFlagsScript = preload("res://gameplay/native_bridge/native_feature_flags.gd")


func test_transport_codec_keeps_json_wire_when_native_execute_disabled() -> void:
	var old_enabled := NativeFeatureFlagsScript.enable_native_battle_message_codec
	var old_shadow := NativeFeatureFlagsScript.enable_native_battle_message_codec_shadow
	var old_execute := NativeFeatureFlagsScript.enable_native_battle_message_codec_execute
	NativeFeatureFlagsScript.enable_native_battle_message_codec = true
	NativeFeatureFlagsScript.enable_native_battle_message_codec_shadow = true
	NativeFeatureFlagsScript.enable_native_battle_message_codec_execute = false

	var payload := TransportMessageCodecScript.encode_message({
		"message_type": TransportMessageTypesScript.INPUT_ACK,
		"peer_id": 2,
		"ack_tick": 11,
	})
	var decoded := TransportMessageCodecScript.decode_message(payload)

	assert_false(payload.size() >= 4 and payload[0] == 81 and payload[1] == 81 and payload[2] == 84 and payload[3] == 83)
	assert_eq(String(decoded.get("message_type", "")), TransportMessageTypesScript.INPUT_ACK)
	assert_eq(int(decoded.get("ack_tick", 0)), 11)

	NativeFeatureFlagsScript.enable_native_battle_message_codec = old_enabled
	NativeFeatureFlagsScript.enable_native_battle_message_codec_shadow = old_shadow
	NativeFeatureFlagsScript.enable_native_battle_message_codec_execute = old_execute


func test_transport_codec_decodes_native_payload_when_present() -> void:
	var old_enabled := NativeFeatureFlagsScript.enable_native_battle_message_codec
	var old_execute := NativeFeatureFlagsScript.enable_native_battle_message_codec_execute
	NativeFeatureFlagsScript.enable_native_battle_message_codec = true
	NativeFeatureFlagsScript.enable_native_battle_message_codec_execute = false

	var native_codec: Object = ClassDB.instantiate("QQTNativeBattleMessageCodec")
	var payload: PackedByteArray = native_codec.call("encode_message", {
		"message_type": TransportMessageTypesScript.STATE_SUMMARY,
		"tick": 22,
	})
	var decoded := TransportMessageCodecScript.decode_message(payload)

	assert_eq(String(decoded.get("message_type", "")), TransportMessageTypesScript.STATE_SUMMARY)
	assert_eq(String(decoded.get("msg_type", "")), TransportMessageTypesScript.STATE_SUMMARY)
	assert_eq(int(decoded.get("tick", 0)), 22)

	NativeFeatureFlagsScript.enable_native_battle_message_codec = old_enabled
	NativeFeatureFlagsScript.enable_native_battle_message_codec_execute = old_execute


func test_transport_codec_uses_native_wire_when_execute_enabled() -> void:
	var old_enabled := NativeFeatureFlagsScript.enable_native_battle_message_codec
	var old_shadow := NativeFeatureFlagsScript.enable_native_battle_message_codec_shadow
	var old_execute := NativeFeatureFlagsScript.enable_native_battle_message_codec_execute
	NativeFeatureFlagsScript.enable_native_battle_message_codec = true
	NativeFeatureFlagsScript.enable_native_battle_message_codec_shadow = true
	NativeFeatureFlagsScript.enable_native_battle_message_codec_execute = true

	var payload := TransportMessageCodecScript.encode_message({
		"message_type": TransportMessageTypesScript.INPUT_ACK,
		"peer_id": 2,
		"ack_tick": 33,
	})
	var decoded := TransportMessageCodecScript.decode_message(payload)

	assert_true(payload.size() >= 4 and payload[0] == 81 and payload[1] == 81 and payload[2] == 84 and payload[3] == 83)
	assert_eq(String(decoded.get("message_type", "")), TransportMessageTypesScript.INPUT_ACK)
	assert_eq(int(decoded.get("ack_tick", 0)), 33)

	NativeFeatureFlagsScript.enable_native_battle_message_codec = old_enabled
	NativeFeatureFlagsScript.enable_native_battle_message_codec_shadow = old_shadow
	NativeFeatureFlagsScript.enable_native_battle_message_codec_execute = old_execute


func test_transport_codec_mixed_json_and_native_payloads_decode_with_metrics() -> void:
	var old_enabled := NativeFeatureFlagsScript.enable_native_battle_message_codec
	var old_shadow := NativeFeatureFlagsScript.enable_native_battle_message_codec_shadow
	var old_execute := NativeFeatureFlagsScript.enable_native_battle_message_codec_execute
	NativeFeatureFlagsScript.enable_native_battle_message_codec = true
	NativeFeatureFlagsScript.enable_native_battle_message_codec_shadow = true
	NativeFeatureFlagsScript.enable_native_battle_message_codec_execute = true
	TransportMessageCodecScript.reset_metrics()

	var native_payload := TransportMessageCodecScript.encode_message({
		"message_type": TransportMessageTypesScript.CHECKPOINT,
		"tick": 40,
		"players": [],
		"bubbles": [],
		"items": [],
	})
	NativeFeatureFlagsScript.enable_native_battle_message_codec_execute = false
	var json_payload := TransportMessageCodecScript.encode_message({
		"message_type": TransportMessageTypesScript.INPUT_ACK,
		"peer_id": 2,
		"ack_tick": 41,
	})

	var native_decoded := TransportMessageCodecScript.decode_message(native_payload)
	var json_decoded := TransportMessageCodecScript.decode_message(json_payload)
	var malformed_decoded := TransportMessageCodecScript.decode_message(PackedByteArray([81, 81, 84, 83, 0, 1, 0, 0, 0, 0, 0, 10]))
	var metrics := TransportMessageCodecScript.get_metrics()

	assert_eq(String(native_decoded.get("message_type", "")), TransportMessageTypesScript.CHECKPOINT)
	assert_eq(int(native_decoded.get("tick", 0)), 40)
	assert_eq(String(json_decoded.get("message_type", "")), TransportMessageTypesScript.INPUT_ACK)
	assert_eq(int(json_decoded.get("ack_tick", 0)), 41)
	assert_true(malformed_decoded.is_empty())
	assert_eq(int(metrics.get("native_decode_count", 0)), 1)
	assert_eq(int(metrics.get("json_decode_count", 0)), 1)
	assert_eq(int(metrics.get("malformed_count", 0)), 1)

	NativeFeatureFlagsScript.enable_native_battle_message_codec = old_enabled
	NativeFeatureFlagsScript.enable_native_battle_message_codec_shadow = old_shadow
	NativeFeatureFlagsScript.enable_native_battle_message_codec_execute = old_execute
