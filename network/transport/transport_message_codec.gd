class_name TransportMessageCodec
extends RefCounted

const NativeFeatureFlagsScript = preload("res://gameplay/native_bridge/native_feature_flags.gd")
const NativeKernelRuntimeScript = preload("res://gameplay/native_bridge/native_kernel_runtime.gd")

const MESSAGE_TYPE_KEY := "message_type"
const MESSAGE_TYPE_ALIAS_KEY := "msg_type"

static var _metrics: Dictionary = {
	"native_decode_count": 0,
	"malformed_count": 0,
}


static func normalize_message(message: Dictionary) -> Dictionary:
	var normalized := message.duplicate(true)
	if normalized.has(MESSAGE_TYPE_ALIAS_KEY) and not normalized.has(MESSAGE_TYPE_KEY):
		normalized[MESSAGE_TYPE_KEY] = normalized[MESSAGE_TYPE_ALIAS_KEY]
	elif normalized.has(MESSAGE_TYPE_KEY) and not normalized.has(MESSAGE_TYPE_ALIAS_KEY):
		normalized[MESSAGE_TYPE_ALIAS_KEY] = normalized[MESSAGE_TYPE_KEY]
	return normalized


static func encode_message(message: Dictionary) -> PackedByteArray:
	var normalized := normalize_message(message)
	if NativeFeatureFlagsScript.enable_native_battle_message_codec:
		var native_codec := NativeKernelRuntimeScript.get_battle_message_codec_kernel()
		if native_codec != null:
			return native_codec.call("encode_message", normalized)
	push_error("[transport_message_codec] native battle message codec is unavailable")
	return PackedByteArray()


static func decode_message(payload: Variant) -> Dictionary:
	if payload is PackedByteArray:
		if NativeFeatureFlagsScript.enable_native_battle_message_codec:
			var native_codec := NativeKernelRuntimeScript.get_battle_message_codec_kernel()
			if native_codec != null and bool(native_codec.call("is_native_payload", payload)):
				var native_decoded: Dictionary = native_codec.call("decode_message", payload)
				if not native_decoded.is_empty():
					_metrics["native_decode_count"] = int(_metrics.get("native_decode_count", 0)) + 1
					return normalize_message(native_decoded)
				_metrics["malformed_count"] = int(_metrics.get("malformed_count", 0)) + 1
				return {}
		_metrics["malformed_count"] = int(_metrics.get("malformed_count", 0)) + 1
		return {}
	if payload is Dictionary:
		return normalize_message(payload)
	return {}


static func get_metrics() -> Dictionary:
	return _metrics.duplicate(true)


static func reset_metrics() -> void:
	_metrics = {
		"native_decode_count": 0,
		"malformed_count": 0,
	}
