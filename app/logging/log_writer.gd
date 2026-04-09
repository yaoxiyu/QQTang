## 日志写入器（负责实际写入文件）
class_name LogWriter
extends RefCounted

var _file: FileAccess = null
var _path: String = ""
var _mutex: Mutex = null

## 初始化日志写入器
func initialize(path: String) -> Error:
	_path = path
	_mutex = Mutex.new()
	
	## 确保目录存在
	var err := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	if err != OK:
		push_error("[LogWriter] Failed to create logs directory: %s" % err)
		return err
	
	## 打开文件（追加模式；不存在时自动创建）
	_file = FileAccess.open(path, FileAccess.READ_WRITE if FileAccess.file_exists(path) else FileAccess.WRITE_READ)
	if _file == null:
		err = FileAccess.get_open_error()
		push_error("[LogWriter] Failed to open log file: %s, error: %s" % [path, err])
		return err
	
	## 移动到文件末尾（追加模式）
	_file.seek_end()
	return OK

## 写入日志行
func write_line(line: String) -> void:
	if _file == null or not _file.is_open():
		return
	
	_mutex.lock()
	_file.store_line(line)
	_mutex.unlock()


func flush() -> void:
	if _file == null or not _file.is_open():
		return

	_mutex.lock()
	_file.flush()
	_mutex.unlock()

## 获取当前文件大小
func get_file_size() -> int:
	if _file == null:
		return 0
	_mutex.lock()
	var size := _file.get_length()
	_mutex.unlock()
	return size

## 轮转日志文件
func rotate() -> Error:
	if _mutex != null:
		_mutex.lock()
	if _file != null and _file.is_open():
		_file.flush()
		_file.close()
	if _mutex != null:
		_mutex.unlock()
	
	## 重命名当前文件为 .log.1, .log.2, 等
	var dir := DirAccess.open(_path.get_base_dir())
	if dir == null:
		return ERR_CANT_CREATE
	
	## 删除最旧的日志文件
	var max_index := _get_max_log_index()
	for i in range(max_index, 0, -1):
		var old_name := "%s.%d" % [_path.get_file(), i]
		var new_name := "%s.%d" % [_path.get_file(), i + 1]
		if dir.file_exists(old_name):
			dir.rename(old_name, new_name)
	
	## 重命名当前文件
	dir.rename(_path.get_file(), "%s.1" % _path.get_file())
	
	## 删除超出保留数量的文件
	_cleanup_old_files(dir)
	
	## 重新打开新文件
	return initialize(_path)

## 关闭写入器
func close() -> void:
	if _file != null and _file.is_open():
		_file.close()
		_file = null
	if _mutex != null:
		_mutex = null

## 获取最大日志索引
func _get_max_log_index() -> int:
	var dir := DirAccess.open(_path.get_base_dir())
	if dir == null:
		return 0
	
	var max_index := 0
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.begins_with(_path.get_file()) and file_name.contains(".log."):
			var parts := file_name.split(".log.")
			if parts.size() == 2:
				var index := parts[1].to_int()
				if index > max_index:
					max_index = index
		file_name = dir.get_next()
	dir.list_dir_end()
	
	return max_index

## 清理旧日志文件
func _cleanup_old_files(dir: DirAccess) -> void:
	var max_index := _get_max_log_index()
	var config := LogManager.get_config()
	
	for i in range(max_index, config.rotation_max_files, -1):
		var file_path := "%s.%d" % [_path.get_file(), i]
		if dir.file_exists(file_path):
			dir.remove(file_path)
