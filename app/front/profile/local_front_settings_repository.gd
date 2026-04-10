class_name LocalFrontSettingsRepository
extends FrontSettingsRepository

const LogFrontScript = preload("res://app/logging/log_front.gd")
const LocalFrontStorageSlotScript = preload("res://app/front/profile/local_front_storage_slot.gd")

const SAVE_BASENAME := "front_settings"


func load_settings() -> FrontSettingsState:
	var save_path := _get_save_path()
	if not FileAccess.file_exists(save_path):
		return FrontSettingsState.new()

	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		_log_load_warning("open_failed", {})
		return FrontSettingsState.new()

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
		return FrontSettingsState.from_dict(parsed)
	_log_load_warning("root_not_dictionary", {
		"type": typeof(parsed),
	})
	return _repair_and_return_default()


func save_settings(settings: FrontSettingsState) -> bool:
	var safe_settings := settings if settings != null else FrontSettingsState.new()
	var file := FileAccess.open(_get_save_path(), FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(safe_settings.to_dict()))
	return true


func _log_load_warning(reason: String, details: Dictionary) -> void:
	if not LogManager.is_initialized():
		return
	var payload := details.duplicate(true)
	payload["reason"] = reason
	payload["path"] = _get_save_path()
	LogFrontScript.warn("front_settings_load_fallback %s" % JSON.stringify(payload), "", 0, "front.settings.repository")


func _repair_and_return_default() -> FrontSettingsState:
	var settings := FrontSettingsState.new()
	save_settings(settings)
	return settings


func _get_save_path() -> String:
	return LocalFrontStorageSlotScript.build_save_path(SAVE_BASENAME)
