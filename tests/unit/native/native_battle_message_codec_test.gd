extends QQTUnitTest

const TransportMessageTypesScript = preload("res://network/transport/transport_message_types.gd")


func test_native_battle_message_codec_roundtrips_low_frequency_generic_message() -> void:
	var codec: Object = ClassDB.instantiate("QQTNativeBattleMessageCodec")
	assert_not_null(codec)
	assert_eq(String(codec.call("get_kernel_version")), "sync_kernel_v1")
	var original := {
		"message_type": TransportMessageTypesScript.PING,
		"tick": 12,
	}
	var payload: PackedByteArray = codec.call("encode_message", original)
	assert_true(bool(codec.call("is_native_payload", payload)))
	var decoded: Dictionary = codec.call("decode_message", payload)
	assert_eq(String(decoded.get("message_type", "")), TransportMessageTypesScript.PING)
	assert_eq(int(decoded.get("tick", 0)), 12)


func test_native_battle_message_codec_roundtrips_ack_summary_checkpoint() -> void:
	var codec: Object = ClassDB.instantiate("QQTNativeBattleMessageCodec")
	for message in [
		{"message_type": TransportMessageTypesScript.INPUT_ACK, "peer_id": 2, "ack_tick": 7},
		{"message_type": TransportMessageTypesScript.CHECKPOINT, "tick": 10, "players": [], "bubbles": [], "items": []},
	]:
		var payload: PackedByteArray = codec.call("encode_message", message)
		var decoded: Dictionary = codec.call("decode_message", payload)
		assert_eq(String(decoded.get("message_type", "")), String(message.get("message_type", "")))

	var summary := {
		"message_type": TransportMessageTypesScript.STATE_SUMMARY,
		"wire_version": 2,
		"tick": 8,
		"checksum": 123,
		"match_phase": 1,
		"remaining_ticks": 300,
		"player_summary": [],
		"events": [],
	}
	var summary_payload: PackedByteArray = codec.call("encode_state_summary_v2", summary)
	var summary_decoded: Dictionary = codec.call("decode_message", summary_payload)
	assert_eq(String(summary_decoded.get("message_type", "")), TransportMessageTypesScript.STATE_SUMMARY)
	assert_eq(int(summary_decoded.get("wire_version", 0)), 2)
	assert_eq(int(summary_decoded.get("tick", 0)), 8)


func test_native_battle_message_codec_roundtrips_input_batch_and_state_delta_v2() -> void:
	var codec: Object = ClassDB.instantiate("QQTNativeBattleMessageCodec")
	var input_batch := {
		"message_type": TransportMessageTypesScript.INPUT_BATCH,
		"wire_version": 2,
		"protocol_version": 2,
		"peer_id": 16752745,
		"controlled_peer_id": 16752745,
		"client_batch_seq": 9,
		"ack_base_tick": 4,
		"first_tick": 5,
		"latest_tick": 6,
		"frame_count": 1,
		"flags": 0,
		"frames": [{"tick_delta": 1, "seq": 6, "move_x": 1, "move_y": 0, "action_bits": 1, "flags": 1}],
	}
	var input_payload: PackedByteArray = codec.call("encode_input_batch_v2", input_batch)
	var input_decoded: Dictionary = codec.call("decode_message", input_payload)
	assert_eq(String(input_decoded.get("message_type", "")), TransportMessageTypesScript.INPUT_BATCH)
	assert_eq(int(input_decoded.get("wire_version", 0)), 2)
	assert_eq(int(input_decoded.get("peer_id", 0)), 16752745)
	assert_eq(int(input_decoded.get("controlled_peer_id", 0)), 16752745)
	assert_eq(int(((input_decoded.get("frames", []) as Array)[0] as Dictionary).get("tick_delta", 0)), 1)

	var delta := {
		"message_type": TransportMessageTypesScript.STATE_DELTA,
		"wire_version": 2,
		"tick": 10,
		"base_tick": 9,
		"changed_bubbles": [{"entity_id": 3, "owner_player_id": 2, "cell_x": 4, "cell_y": 5, "alive": true}],
		"removed_bubble_ids": [1],
		"changed_items": [{"entity_id": 7, "item_type": 2, "cell_x": 1, "cell_y": 2, "visible": true}],
		"removed_item_ids": [6],
		"event_details": [],
	}
	var delta_payload: PackedByteArray = codec.call("encode_state_delta_v2", delta)
	var delta_decoded: Dictionary = codec.call("decode_message", delta_payload)
	assert_eq(String(delta_decoded.get("message_type", "")), TransportMessageTypesScript.STATE_DELTA)
	assert_eq(int(delta_decoded.get("tick", 0)), 10)
	assert_eq((delta_decoded.get("changed_bubbles", []) as Array).size(), 1)


func test_native_battle_message_codec_malformed_payload_returns_empty() -> void:
	var codec: Object = ClassDB.instantiate("QQTNativeBattleMessageCodec")
	var malformed := PackedByteArray([81, 81, 84, 83, 0, 1, 0, 0, 0, 0, 0, 10])
	var decoded: Dictionary = codec.call("decode_message", malformed)
	var metrics: Dictionary = codec.call("get_metrics")
	assert_true(decoded.is_empty())
	assert_eq(int(metrics.get("malformed_count", 0)), 1)

