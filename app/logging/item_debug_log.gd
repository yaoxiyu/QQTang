class_name ItemDebugLog
extends RefCounted

static var _file: FileAccess = null
static var _opened: bool = false
static var _log_path: String = ""


static func write(message: String) -> void:
	if not _opened:
		_open()
	if _file == null:
		return
	_file.store_line("%s %s" % [Time.get_datetime_string_from_system(), message])
	_file.flush()


static func _open() -> void:
	_opened = true
	var fs_path := ProjectSettings.globalize_path("res://logs")
	var dir := DirAccess.open(fs_path)
	if dir == null:
		DirAccess.make_dir_recursive_absolute(fs_path)
		dir = DirAccess.open(fs_path)
	if dir == null:
		return
	var timestamp := Time.get_datetime_string_from_system().replace(":", "-")
	_log_path = "res://logs/item_debug_%s.log" % timestamp
	var log_fs_path := ProjectSettings.globalize_path(_log_path)
	_file = FileAccess.open(log_fs_path, FileAccess.WRITE_READ)
	if _file != null:
		_file.seek_end()


static func close() -> void:
	if _file != null:
		_file.close()
		_file = null
	_opened = false
