class_name ContentHashUtil
extends RefCounted


static func hash_variant(value: Variant) -> String:
	var canonical_value: Variant = _canonicalize(value)
	var canonical_json: String = JSON.stringify(canonical_value, "", true, true)
	return canonical_json.sha256_text()


static func hash_dictionary(value: Dictionary) -> String:
	return hash_variant(value)


static func hash_array(value: Array) -> String:
	return hash_variant(value)


static func _canonicalize(value: Variant) -> Variant:
	if value is Dictionary:
		var keys: Array[String] = []
		for key in value.keys():
			keys.append(String(key))
		keys.sort()
		var result: Dictionary = {}
		for key in keys:
			result[key] = _canonicalize(value.get(key))
		return result

	if value is Array:
		var result_array: Array = []
		for item in value:
			result_array.append(_canonicalize(item))
		return result_array

	if value is PackedStringArray:
		var packed_result: Array[String] = []
		for item in value:
			packed_result.append(String(item))
		return packed_result

	if value is Vector2i:
		var vec2i := value as Vector2i
		return {"x": vec2i.x, "y": vec2i.y}

	if value is Vector2:
		var vec2 := value as Vector2
		return {"x": vec2.x, "y": vec2.y}

	return value
