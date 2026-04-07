class_name LocalFrontSettingsRepository
extends FrontSettingsRepository

const SAVE_PATH := "user://front_settings.save"


func load_settings() -> FrontSettingsState:
	if not FileAccess.file_exists(SAVE_PATH):
		return FrontSettingsState.new()

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return FrontSettingsState.new()

	var parsed : Dictionary = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		return FrontSettingsState.from_dict(parsed)
	return FrontSettingsState.new()


func save_settings(settings: FrontSettingsState) -> bool:
	var safe_settings := settings if settings != null else FrontSettingsState.new()
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(safe_settings.to_dict()))
	return true
