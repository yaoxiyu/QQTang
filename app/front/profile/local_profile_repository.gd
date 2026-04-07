class_name LocalProfileRepository
extends ProfileRepository

const SAVE_PATH := "user://front_profile.save"


func load_profile() -> PlayerProfileState:
	if not FileAccess.file_exists(SAVE_PATH):
		return PlayerProfileState.new()

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return PlayerProfileState.new()

	var parsed : Dictionary = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		return PlayerProfileState.from_dict(parsed)
	return PlayerProfileState.new()


func save_profile(profile: PlayerProfileState) -> bool:
	var safe_profile := profile if profile != null else PlayerProfileState.new()
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(safe_profile.to_dict()))
	return true
