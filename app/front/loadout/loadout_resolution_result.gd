class_name LoadoutResolutionResult
extends RefCounted

var character_id: String = ""
var bubble_style_id: String = ""
var changed_fields: Array[String] = []


func to_dict() -> Dictionary:
	return {
		"character_id": character_id,
		"bubble_style_id": bubble_style_id,
		"changed_fields": changed_fields.duplicate(),
	}


func mark_changed(field_name: String) -> void:
	if field_name.is_empty() or changed_fields.has(field_name):
		return
	changed_fields.append(field_name)
