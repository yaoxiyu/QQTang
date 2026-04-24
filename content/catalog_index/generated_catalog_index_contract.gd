class_name GeneratedCatalogIndexContract
extends RefCounted


static func validate_payload(payload: Dictionary, expected_kind: String) -> Array[String]:
	var errors: Array[String] = []
	if payload.is_empty():
		errors.append("payload is empty")
		return errors
	if int(payload.get("schema_version", 0)) <= 0:
		errors.append("schema_version missing")
	if String(payload.get("content_kind", "")) != expected_kind:
		errors.append("content_kind mismatch")
	var entries = payload.get("entries", null)
	if not entries is Array:
		errors.append("entries must be array")
		return errors
	var seen := {}
	for entry_variant in entries:
		if not entry_variant is Dictionary:
			errors.append("entry must be dictionary")
			continue
		var entry := entry_variant as Dictionary
		var id := String(entry.get("id", ""))
		if id.is_empty():
			errors.append("entry id missing")
		elif seen.has(id):
			errors.append("duplicate entry id: %s" % id)
		else:
			seen[id] = true
	return errors
