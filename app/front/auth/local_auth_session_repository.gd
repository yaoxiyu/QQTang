class_name LocalAuthSessionRepository
extends AuthSessionRepository

const AuthSessionStateScript = preload("res://app/front/auth/auth_session_state.gd")
const DeviceSecretRepositoryScript = preload("res://app/front/auth/device_secret_repository.gd")
const LocalFrontStorageSlotScript = preload("res://app/front/profile/local_front_storage_slot.gd")

const SAVE_BASENAME := "auth_session"

var _device_secret_repository: DeviceSecretRepository = null


func _init(device_secret_repository: DeviceSecretRepository = null) -> void:
	_device_secret_repository = device_secret_repository if device_secret_repository != null else DeviceSecretRepositoryScript.new()


func load_session() -> AuthSessionState:
	var save_path := _get_save_path()
	if not FileAccess.file_exists(save_path):
		return AuthSessionStateScript.new()
	var file := FileAccess.open_encrypted_with_pass(save_path, FileAccess.READ, _get_secret())
	if file == null:
		return AuthSessionStateScript.new()
	var text := file.get_as_text()
	if text.strip_edges().is_empty():
		return _repair_and_return_default()
	var json := JSON.new()
	if json.parse(text) != OK:
		return _repair_and_return_default()
	if json.data is Dictionary:
		return AuthSessionStateScript.from_dict(json.data)
	return _repair_and_return_default()


func save_session(state: AuthSessionState) -> bool:
	var safe_state := state if state != null else AuthSessionStateScript.new()
	var file := FileAccess.open_encrypted_with_pass(_get_save_path(), FileAccess.WRITE, _get_secret())
	if file == null:
		return false
	file.store_string(JSON.stringify(safe_state.to_dict()))
	return true


func clear_session() -> void:
	var save_path := _get_save_path()
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)


func _repair_and_return_default() -> AuthSessionState:
	var state := AuthSessionStateScript.new()
	save_session(state)
	return state


func _get_secret() -> String:
	return _device_secret_repository.load_or_create_secret()


func _get_save_path() -> String:
	return LocalFrontStorageSlotScript.build_save_path(SAVE_BASENAME)
