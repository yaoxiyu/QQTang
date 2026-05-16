class_name TransportMessageCodec
extends RefCounted

const NativeFeatureFlagsScript = preload("res://gameplay/native_bridge/native_feature_flags.gd")
const NativeKernelRuntimeScript = preload("res://gameplay/native_bridge/native_kernel_runtime.gd")

const MESSAGE_TYPE_KEY := "message_type"
const HIGH_FREQUENCY_MESSAGE_TYPES := ["INPUT_BATCH", "STATE_SUMMARY", "STATE_DELTA"]

static var _metrics: Dictionary = {
	"native_decode_count": 0,
	"malformed_count": 0,
	"input_batch_v2_encode_count": 0,
	"input_batch_v2_decode_count": 0,
	"state_summary_v2_encode_count": 0,
	"state_summary_v2_decode_count": 0,
	"state_delta_v2_encode_count": 0,
	"state_delta_v2_decode_count": 0,
}


static func encode_message(message: Dictionary) -> PackedByteArray:
	var normalized := message.duplicate(true)
	if NativeFeatureFlagsScript.enable_native_battle_message_codec:
		var native_codec := NativeKernelRuntimeScript.get_battle_message_codec_kernel()
		if native_codec != null:
			match String(normalized.get(MESSAGE_TYPE_KEY, "")):
				"INPUT_BATCH":
					_metrics["input_batch_v2_encode_count"] = int(_metrics.get("input_batch_v2_encode_count", 0)) + 1
					return native_codec.call("encode_input_batch_v2", normalized)
				"STATE_SUMMARY":
					_metrics["state_summary_v2_encode_count"] = int(_metrics.get("state_summary_v2_encode_count", 0)) + 1
					return native_codec.call("encode_state_summary_v2", normalized)
				"STATE_DELTA":
					_metrics["state_delta_v2_encode_count"] = int(_metrics.get("state_delta_v2_encode_count", 0)) + 1
					return native_codec.call("encode_state_delta_v2", normalized)
				_:
					return native_codec.call("encode_message", normalized)
	push_error("[transport_message_codec] native battle message codec is unavailable")
	return PackedByteArray()


static func decode_message(payload: Variant) -> Dictionary:
	if payload is PackedByteArray:
		if NativeFeatureFlagsScript.enable_native_battle_message_codec:
			var native_codec := NativeKernelRuntimeScript.get_battle_message_codec_kernel()
			if native_codec != null and bool(native_codec.call("is_native_payload", payload)):
				var message_type := String(native_codec.call("detect_message_type", payload)) if native_codec.has_method("detect_message_type") else ""
				var native_decoded: Dictionary = {}
				match message_type:
					"INPUT_BATCH":
						native_decoded = native_codec.call("decode_input_batch_v2", payload)
						if not native_decoded.is_empty():
							_metrics["input_batch_v2_decode_count"] = int(_metrics.get("input_batch_v2_decode_count", 0)) + 1
					"STATE_SUMMARY":
						native_decoded = native_codec.call("decode_state_summary_v2", payload)
						if not native_decoded.is_empty():
							_metrics["state_summary_v2_decode_count"] = int(_metrics.get("state_summary_v2_decode_count", 0)) + 1
					"STATE_DELTA":
						native_decoded = native_codec.call("decode_state_delta_v2", payload)
						if not native_decoded.is_empty():
							_metrics["state_delta_v2_decode_count"] = int(_metrics.get("state_delta_v2_decode_count", 0)) + 1
					_:
						native_decoded = native_codec.call("decode_message", payload)
				if not native_decoded.is_empty():
					_metrics["native_decode_count"] = int(_metrics.get("native_decode_count", 0)) + 1
					return native_decoded.duplicate(true)
				_metrics["malformed_count"] = int(_metrics.get("malformed_count", 0)) + 1
				return {}
		_metrics["malformed_count"] = int(_metrics.get("malformed_count", 0)) + 1
		return {}
	if payload is Dictionary:
		var normalized_dict: Dictionary = (payload as Dictionary).duplicate(true)
		if HIGH_FREQUENCY_MESSAGE_TYPES.has(String(normalized_dict.get(MESSAGE_TYPE_KEY, ""))):
			_metrics["malformed_count"] = int(_metrics.get("malformed_count", 0)) + 1
			return {}
		return normalized_dict
	return {}


static func get_metrics() -> Dictionary:
	return _metrics.duplicate(true)


static func reset_metrics() -> void:
	_metrics = {
		"native_decode_count": 0,
		"malformed_count": 0,
		"input_batch_v2_encode_count": 0,
		"input_batch_v2_decode_count": 0,
		"state_summary_v2_encode_count": 0,
		"state_summary_v2_decode_count": 0,
		"state_delta_v2_encode_count": 0,
		"state_delta_v2_decode_count": 0,
	}
