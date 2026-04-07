class_name FrontSettingsRepository
extends RefCounted


func load_settings() -> FrontSettingsState:
	return FrontSettingsState.new()


func save_settings(settings: FrontSettingsState) -> bool:
	return settings != null
