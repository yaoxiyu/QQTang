class_name QQTTestRuntimeHelper
extends RefCounted


static func create_temp_dir(prefix: String = "qqt_test") -> String:
	var base_path := "user://tests_tmp"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(base_path))
	var temp_name := "%s_%d_%d" % [prefix, Time.get_unix_time_from_system(), randi()]
	var temp_path := base_path.path_join(temp_name)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(temp_path))
	return temp_path


static func remove_temp_dir(path: String) -> void:
	if path.is_empty():
		return
	var absolute_path := ProjectSettings.globalize_path(path)
	if not DirAccess.dir_exists_absolute(absolute_path):
		return
	_remove_dir_recursive(absolute_path)


static func read_text_file(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	return file.get_as_text()


static func write_text_file(path: String, content: String) -> Error:
	var directory_path := path.get_base_dir()
	if not directory_path.is_empty():
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory_path))
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return ERR_CANT_CREATE
	file.store_string(content)
	return OK


static func _remove_dir_recursive(absolute_dir_path: String) -> void:
	var dir := DirAccess.open(absolute_dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	while true:
		var name := dir.get_next()
		if name.is_empty():
			break
		if name == "." or name == "..":
			continue
		var child_path := absolute_dir_path.path_join(name)
		if dir.current_is_dir():
			_remove_dir_recursive(child_path)
			DirAccess.remove_absolute(child_path)
		else:
			DirAccess.remove_absolute(child_path)
	dir.list_dir_end()
	DirAccess.remove_absolute(absolute_dir_path)
