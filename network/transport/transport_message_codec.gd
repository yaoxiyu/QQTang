class_name TransportMessageCodec
extends RefCounted

const MESSAGE_TYPE_KEY := "message_type"
const LEGACY_MESSAGE_TYPE_KEY := "msg_type"


static func normalize_message(message: Dictionary) -> Dictionary:
	var normalized := message.duplicate(true)
	if normalized.has(LEGACY_MESSAGE_TYPE_KEY) and not normalized.has(MESSAGE_TYPE_KEY):
		normalized[MESSAGE_TYPE_KEY] = normalized[LEGACY_MESSAGE_TYPE_KEY]
	elif normalized.has(MESSAGE_TYPE_KEY) and not normalized.has(LEGACY_MESSAGE_TYPE_KEY):
		normalized[LEGACY_MESSAGE_TYPE_KEY] = normalized[MESSAGE_TYPE_KEY]
	return normalized


static func encode_message(message: Dictionary) -> PackedByteArray:
	var normalized := normalize_message(message)
	return normalized_to_bytes(normalized)


static func decode_message(payload: Variant) -> Dictionary:
	if payload is PackedByteArray:
		var parsed : Dictionary = JSON.parse_string(payload.get_string_from_utf8())
		if parsed is Dictionary:
			return normalize_message(parsed)
		return {}
	if payload is Dictionary:
		return normalize_message(payload)
	return {}


static func normalized_to_bytes(message: Dictionary) -> PackedByteArray:
	var json := JSON.stringify(message, "", true)
	return json.to_utf8_buffer()
