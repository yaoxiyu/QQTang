class_name LocalFrontStorageSlot
extends RefCounted

const SLOT_ARG := "--qqt-user-slot"
const SLOT_ENV := "QQT_USER_SLOT"


static func build_save_path(base_name: String) -> String:
	var normalized_base := base_name.strip_edges()
	if normalized_base.is_empty():
		normalized_base = "front_settings"
	var slot := _resolve_slot()
	if slot.is_empty():
		return "user://%s.save" % normalized_base
	return "user://%s.%s.save" % [normalized_base, slot]


static func _resolve_slot() -> String:
	var args := OS.get_cmdline_user_args()
	for index in range(args.size()):
		if String(args[index]) != SLOT_ARG:
			continue
		if index + 1 >= args.size():
			return ""
		return _sanitize_slot(String(args[index + 1]))
	var env_slot := OS.get_environment(SLOT_ENV)
	return _sanitize_slot(env_slot)


static func _sanitize_slot(raw_slot: String) -> String:
	var trimmed := raw_slot.strip_edges()
	if trimmed.is_empty():
		return ""
	var sanitized := ""
	for index in range(trimmed.length()):
		var character := trimmed[index]
		if _is_safe_slot_character(character):
			sanitized += character
	if sanitized.is_empty():
		return ""
	return sanitized.substr(0, 32)


static func _is_safe_slot_character(character: String) -> bool:
	if character.length() != 1:
		return false
	var code := character.unicode_at(0)
	return (code >= 48 and code <= 57) \
		or (code >= 65 and code <= 90) \
		or (code >= 97 and code <= 122) \
		or character == "_" \
		or character == "-"
