extends QQTUnitTest


func test_native_battle_message_codec_benchmark_reports_metrics() -> void:
	var codec: Object = ClassDB.instantiate("QQTNativeBattleMessageCodec")
	assert_not_null(codec)
	for index in range(32):
		var payload: PackedByteArray = codec.call("encode_message", {
			"message_type": "INPUT_ACK",
			"peer_id": 2,
			"ack_tick": index,
		})
		codec.call("decode_message", payload)
	var metrics: Dictionary = codec.call("get_metrics")
	assert_eq(int(metrics.get("native_decode_count", 0)), 32)
	assert_eq(int(metrics.get("malformed_count", 0)), 0)
