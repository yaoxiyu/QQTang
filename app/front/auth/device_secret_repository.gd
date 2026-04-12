class_name DeviceSecretRepository
extends RefCounted

const LocalFrontStorageSlotScript = preload("res://app/front/profile/local_front_storage_slot.gd")

const SAVE_BASENAME := "device_secret"


func load_or_create_secret() -> String:
	var save_path := _get_save_path()
	if FileAccess.file_exists(save_path):
		var file := FileAccess.open(save_path, FileAccess.READ)
		if file != null:
			var value := file.get_as_text().strip_edges()
			if not value.is_empty():
				return value
	var secret := _generate_secret()
	var write_file := FileAccess.open(save_path, FileAccess.WRITE)
	if write_file != null:
		write_file.store_string(secret)
	return secret


func _generate_secret() -> String:
	var crypto := Crypto.new()
	var bytes := crypto.generate_random_bytes(32)
	if bytes.is_empty():
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		for index in range(32):
			bytes.append(rng.randi_range(0, 255))
	return Marshalls.raw_to_base64(bytes)


func _get_save_path() -> String:
	return LocalFrontStorageSlotScript.build_save_path(SAVE_BASENAME)
