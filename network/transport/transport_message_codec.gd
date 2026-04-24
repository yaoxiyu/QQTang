class_name TransportMessageCodec
extends RefCounted

const NativeFeatureFlagsScript = preload("res://gameplay/native_bridge/native_feature_flags.gd")
const NativeKernelRuntimeScript = preload("res://gameplay/native_bridge/native_kernel_runtime.gd")

const MESSAGE_TYPE_KEY := "message_type"
const LEGACY_MESSAGE_TYPE_KEY := "msg_type"

static var _metrics: Dictionary = {
	"native_decode_count": 0,
	"json_decode_count": 0,
	"malformed_count": 0,
}


static func normalize_message(message: Dictionary) -> Dictionary:
	var normalized := message.duplicate(true)
	if normalized.has(LEGACY_MESSAGE_TYPE_KEY) and not normalized.has(MESSAGE_TYPE_KEY):
		normalized[MESSAGE_TYPE_KEY] = normalized[LEGACY_MESSAGE_TYPE_KEY]
	elif normalized.has(MESSAGE_TYPE_KEY) and not normalized.has(LEGACY_MESSAGE_TYPE_KEY):
		normalized[LEGACY_MESSAGE_TYPE_KEY] = normalized[MESSAGE_TYPE_KEY]
	return normalized


static func encode_message(message: Dictionary) -> PackedByteArray:
	var normalized := normalize_message(message)
	if NativeFeatureFlagsScript.enable_native_battle_message_codec:
		var native_codec := NativeKernelRuntimeScript.get_battle_message_codec_kernel()
		if native_codec != null:
			if NativeFeatureFlagsScript.enable_native_battle_message_codec_shadow:
				native_codec.call("encode_message", normalized)
			if NativeFeatureFlagsScript.enable_native_battle_message_codec_execute:
				return native_codec.call("encode_message", normalized)
	return normalized_to_bytes(normalized)


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
		var parsed: Variant = JSON.parse_string(payload.get_string_from_utf8())
		if parsed is Dictionary:
			_metrics["json_decode_count"] = int(_metrics.get("json_decode_count", 0)) + 1
			return normalize_message(parsed)
		_metrics["malformed_count"] = int(_metrics.get("malformed_count", 0)) + 1
		return {}
	if payload is Dictionary:
		return normalize_message(payload)
	return {}


static func normalized_to_bytes(message: Dictionary) -> PackedByteArray:
	var json := JSON.stringify(message, "", true)
	return json.to_utf8_buffer()


static func get_metrics() -> Dictionary:
	return _metrics.duplicate(true)


static func reset_metrics() -> void:
	_metrics = {
		"native_decode_count": 0,
		"json_decode_count": 0,
		"malformed_count": 0,
	}
