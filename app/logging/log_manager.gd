## 日志管理器（全局单例模式）
## 使用方式：
##   LogManager.debug(LogType.NET, "Connection established")
##   LogManager.warn(LogType.SESSION, "Player timeout", "room_session.gd", 42)
##   LogManager.error(LogType.BATTLE, "Failed to start battle", "battle_bootstrap.gd", 85)
class_name LogManager
extends Object

## 日志配置
static var _config: LogConfig = null

## 日志写入器
static var _writer: LogWriter = null

## 当前日志文件路径
static var _current_log_path: String = ""

## 是否已初始化
static var _initialized: bool = false

## 用于批量 flush/轮转检查，避免每条日志都做磁盘同步
static var _writes_since_flush: int = 0
static var _writes_since_rotation_check: int = 0

## 初始化日志系统（客户端模式）
static func initialize_client() -> Error:
	return _initialize(LogConfig.create_client_config())

## 初始化日志系统（Dedicated Server 模式）
static func initialize_dedicated_server() -> Error:
	return _initialize(LogConfig.create_dedicated_server_config())

## 使用自定义配置初始化
static func initialize_with_config(config: LogConfig) -> Error:
	return _initialize(config)

## 内部初始化逻辑
static func _initialize(config: LogConfig) -> Error:
	if _initialized:
		if not _is_silent_test_config():
			push_warning("[LogManager] Already initialized, reinitializing...")
		_shutdown()
	
	_config = config
	
	## 生成日志文件路径
	var timestamp := Time.get_datetime_string_from_system(false, true).replace(":", "-").replace(" ", "_")
	var process_suffix := "%d_%d" % [OS.get_process_id(), Time.get_ticks_msec()]
	var file_name := "%s%s_%s.%s" % [config.file_prefix, timestamp, process_suffix, config.file_extension]
	_current_log_path = config.log_directory.path_join(file_name)
	
	## 初始化写入器
	_writer = LogWriter.new()
	var err := _writer.initialize(_current_log_path)
	if err != OK:
		push_error("[LogManager] Failed to initialize log writer: %s" % err)
		return err
	
	## 配置 Godot 原生日志（可选，将 Godot 内部日志也写入文件）
	_setup_godot_file_logging()
	
	_initialized = true
	_writes_since_flush = 0
	_writes_since_rotation_check = 0
	
	## 输出初始化信息
	info(LogLevelConstants.Type.APP, "Log system initialized, level: %s, file: %s" % [
		LogLevelConstants.level_to_string(config.min_level),
		_current_log_path
	])
	
	return OK

## 配置 Godot 原生日志（将 Godot 内部日志也写入我们的日志文件）
static func _setup_godot_file_logging() -> void:
	if not _config.file_enabled:
		return
	
	## 设置 Godot 原生日志路径
	ProjectSettings.set_setting("debug/file_logging/enable_file_logging", true)
	ProjectSettings.set_setting("debug/file_logging/log_path", _current_log_path)
	ProjectSettings.set_setting("debug/file_logging/rotate", _config.rotation_enabled)
	ProjectSettings.set_setting("debug/file_logging/rotate_max_files", _config.rotation_max_files)
	
	## 注意：Godot 原生日志不支持自定义级别过滤，我们只负责文件路径配置

## 输出 DEBUG 级别日志
static func debug(log_type: int, message: String, file: String = "", line: int = 0, tag: String = "") -> void:
	_log(LogLevelConstants.Level.DEBUG, log_type, message, file, line, tag)

## 输出 INFO 级别日志
static func info(log_type: int, message: String, file: String = "", line: int = 0, tag: String = "") -> void:
	_log(LogLevelConstants.Level.INFO, log_type, message, file, line, tag)

## 输出 WARN 级别日志
static func warn(log_type: int, message: String, file: String = "", line: int = 0, tag: String = "") -> void:
	_log(LogLevelConstants.Level.WARN, log_type, message, file, line, tag)

## 输出 ERROR 级别日志
static func error(log_type: int, message: String, file: String = "", line: int = 0, tag: String = "") -> void:
	_log(LogLevelConstants.Level.ERROR, log_type, message, file, line, tag)

## 输出 FATAL 级别日志
static func fatal(log_type: int, message: String, file: String = "", line: int = 0, tag: String = "") -> void:
	_log(LogLevelConstants.Level.FATAL, log_type, message, file, line, tag)

## 核心日志方法
static func _log(level: int, log_type: int, message: String, file: String = "", line: int = 0, tag: String = "") -> void:
	if not _initialized:
		push_error("[LogManager] Not initialized, message dropped: %s" % message)
		return
	
	## 检查日志级别
	if level < _config.min_level:
		return

	if _config.location_enabled and file.is_empty():
		var callsite := _detect_callsite()
		file = String(callsite.get("file", ""))
		line = int(callsite.get("line", 0))
	
	## 格式化日志
	var formatted := _format_log_line(level, log_type, message, file, line, tag)
	
	## 输出到控制台
	if _config.console_enabled:
		_output_to_console(level, formatted)
	
	## 输出到文件
	if _config.file_enabled and _writer != null:
		_writer.write_line(formatted)
		_writes_since_flush += 1
		_writes_since_rotation_check += 1

		if _config.flush_on_error and level >= LogLevelConstants.Level.ERROR:
			flush()
		elif _writes_since_flush >= _config.flush_interval_lines:
			flush()

		if _config.rotation_enabled and _writes_since_rotation_check >= _config.rotation_check_interval_lines:
			_check_rotation()

## 格式化日志行
static func _format_log_line(level: int, log_type: int, message: String, file: String = "", line: int = 0, tag: String = "") -> String:
	var result := _config.format_template
	
	## 替换时间戳
	if _config.timestamp_enabled:
		var timestamp := Time.get_datetime_string_from_system(false, true)
		result = result.replace("{timestamp}", timestamp)
	else:
		result = result.replace("{timestamp}", "")
	
	## 替换日志级别
	if _config.level_enabled:
		result = result.replace("{level}", LogLevelConstants.level_to_string(level))
	else:
		result = result.replace("{level}", "")
	
	## 替换日志类型
	if _config.type_enabled:
		result = result.replace("{type}", LogLevelConstants.type_to_string(log_type))
	else:
		result = result.replace("{type}", "")

	result = result.replace("{tag}", "%s " % tag if not tag.is_empty() else "")
	
	## 替换调用位置
	if _config.location_enabled and not file.is_empty():
		var location := "%s:%d" % [file.get_file(), line]
		result = result.replace("{location}", "[%s]" % location)
	else:
		result = result.replace("{location}", "")
	
	## 替换消息
	result = result.replace("{message}", message)
	
	return result

## 输出到控制台
static func _output_to_console(level: int, message: String) -> void:
	match level:
		LogLevelConstants.Level.DEBUG:
			print(message)
		LogLevelConstants.Level.INFO:
			print(message)
		LogLevelConstants.Level.WARN:
			push_warning(message)
		LogLevelConstants.Level.ERROR:
			push_error(message)
		LogLevelConstants.Level.FATAL:
			push_error("FATAL: " + message)

## 检查日志轮转
static func _check_rotation() -> void:
	if _writer == null:
		return
	
	_writer.flush()
	var size := _writer.get_file_size()
	_writes_since_rotation_check = 0
	if size >= _config.rotation_max_size_bytes:
		var err := _writer.rotate()
		if err != OK:
			push_error("[LogManager] Failed to rotate log file: %s" % err)
		else:
			_writes_since_flush = 0
			info(LogLevelConstants.Type.APP, "Log file rotated, new file: %s" % _current_log_path)


static func _detect_callsite() -> Dictionary:
	var stack := get_stack()
	for frame in stack:
		var source := String(frame.get("source", ""))
		if source.is_empty():
			continue
		if source.begins_with("res://app/logging/"):
			continue
		return {
			"file": source,
			"line": int(frame.get("line", 0)),
		}
	return {}

## 获取当前配置
static func get_config() -> LogConfig:
	if _config == null:
		_config = LogConfig.create_client_config()
	return _config

## 设置日志级别
static func set_min_level(level: int) -> void:
	if _config != null:
		_config.min_level = level
		info(LogLevelConstants.Type.APP, "Log level changed to: %s" % LogLevelConstants.level_to_string(level))

## 获取当前日志文件路径
static func get_current_log_path() -> String:
	return _current_log_path


static func is_initialized() -> bool:
	return _initialized

## 刷新日志（确保所有日志已写入文件）
static func flush() -> void:
	if _writer != null:
		_writer.flush()
		_writes_since_flush = 0

## 关闭日志系统
static func _shutdown() -> void:
	if not _initialized:
		_writer = null
		return
	if _writer != null:
		info(LogLevelConstants.Type.APP, "Log system shutting down")
		flush()
		_writer.close()
		_writer = null
	_initialized = false


static func _is_silent_test_config() -> bool:
	return _config != null and not _config.console_enabled and not _config.file_enabled

## 自动关闭（进程退出时调用）
static func on_exit() -> void:
	_shutdown()
