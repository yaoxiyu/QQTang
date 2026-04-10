class_name LocalProfileRepository
extends ProfileRepository

const LogFrontScript = preload("res://app/logging/log_front.gd")
const LocalFrontStorageSlotScript = preload("res://app/front/profile/local_front_storage_slot.gd")

const SAVE_BASENAME := "front_profile"


func load_profile() -> PlayerProfileState:
	var save_path := _get_save_path()
	if not FileAccess.file_exists(save_path):
		return PlayerProfileState.new()

	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		_log_load_warning("open_failed", {})
		return PlayerProfileState.new()

	var text := file.get_as_text()
	if text.strip_edges().is_empty():
		_log_load_warning("empty_file", {})
		return _repair_and_return_default()

	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		_log_load_warning("parse_failed", {
			"error": json.get_error_message(),
			"line": json.get_error_line(),
		})
		return _repair_and_return_default()

	var parsed = json.data
	if parsed is Dictionary:
		return PlayerProfileState.from_dict(parsed)
	_log_load_warning("root_not_dictionary", {
		"type": typeof(parsed),
	})
	return _repair_and_return_default()


func save_profile(profile: PlayerProfileState) -> bool:
	var safe_profile := profile if profile != null else PlayerProfileState.new()
	var file := FileAccess.open(_get_save_path(), FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(safe_profile.to_dict()))
	return true


func _log_load_warning(reason: String, details: Dictionary) -> void:
	if not LogManager.is_initialized():
		return
	var payload := details.duplicate(true)
	payload["reason"] = reason
	payload["path"] = _get_save_path()
	LogFrontScript.warn("front_profile_load_fallback %s" % JSON.stringify(payload), "", 0, "front.profile.repository")


func _repair_and_return_default() -> PlayerProfileState:
	var profile := PlayerProfileState.new()
	save_profile(profile)
	return profile


func _get_save_path() -> String:
	return LocalFrontStorageSlotScript.build_save_path(SAVE_BASENAME)
