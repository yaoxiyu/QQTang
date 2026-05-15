## 日志系统配置
class_name LogConfig
extends RefCounted

## 日志级别阈值（低于此级别的日志不会被输出）
var min_level: int = LogLevelConstants.Level.DEBUG

## 是否输出到控制台
var console_enabled: bool = true

## 是否输出到文件
var file_enabled: bool = true

## 日志文件目录（运行时可写目录）
var log_directory: String = "user://logs"

## 日志文件前缀（client_ 或 dedicated_server_）
var file_prefix: String = "client_"

## 日志文件扩展名
var file_extension: String = "log"

## 是否启用日志轮转（按大小）
var rotation_enabled: bool = true

## 单个日志文件最大大小（字节，默认 10MB）
var rotation_max_size_bytes: int = 10 * 1024 * 1024

## 保留的日志文件数量（默认 5 个）
var rotation_max_files: int = 5

## 是否包含时间戳
var timestamp_enabled: bool = true

## 是否包含日志级别
var level_enabled: bool = true

## 是否包含日志类型
var type_enabled: bool = true

## 是否包含调用位置（文件:行号）
var location_enabled: bool = false

## 日志格式模板（支持占位符：{timestamp} {level} {type} {tag} {message} {location}）
var format_template: String = "[{timestamp}] [{level}] [{type}] {tag}{message}"

## 写入多少行后主动 flush 一次
var flush_interval_lines: int = 32

## 写入多少行后检查一次轮转
var rotation_check_interval_lines: int = 64

## ERROR/FATAL 是否立即 flush
var flush_on_error: bool = true

## 创建默认客户端配置
static func create_client_config() -> LogConfig:
	var config := LogConfig.new()
	config.file_prefix = "client_"
	config.location_enabled = false
	config.min_level = LogLevelConstants.Level.DEBUG if OS.is_debug_build() else LogLevelConstants.Level.INFO
	config.log_directory = _resolve_log_directory()
	return config

## 创建默认 Dedicated Server 配置
static func create_dedicated_server_config() -> LogConfig:
	var config := LogConfig.new()
	config.file_prefix = "dedicated_server_"
	config.location_enabled = true
	config.min_level = LogLevelConstants.Level.DEBUG if OS.is_debug_build() else LogLevelConstants.Level.INFO
	config.log_directory = _resolve_log_directory()
	if _is_dev_runtime():
		# Dev DS is often terminated by launcher/script; flush each line to avoid empty files.
		config.flush_interval_lines = 1
	return config

## 创建开发环境配置（更详细的日志）
static func create_debug_config() -> LogConfig:
	var config := LogConfig.new()
	config.min_level = LogLevelConstants.Level.DEBUG
	config.location_enabled = true
	config.log_directory = _resolve_log_directory()
	return config

## 创建生产环境配置（仅 INFO 及以上）
static func create_release_config() -> LogConfig:
	var config := LogConfig.new()
	config.min_level = LogLevelConstants.Level.INFO
	config.location_enabled = false
	config.console_enabled = false  # 生产环境关闭控制台输出
	config.log_directory = _resolve_log_directory()
	return config


static func _resolve_log_directory() -> String:
	var env_log_dir := OS.get_environment("QQT_LOG_DIR").strip_edges()
	if not env_log_dir.is_empty():
		return env_log_dir
	if _is_dev_runtime():
		return ProjectSettings.globalize_path("res://logs")
	return "user://logs"


static func _is_dev_runtime() -> bool:
	for raw_arg in OS.get_cmdline_user_args():
		var arg := String(raw_arg).strip_edges()
		if arg == "--qqt-dev-mode":
			return true
		if arg.begins_with("--qqt-dev-launcher-"):
			return true
		if arg.begins_with("--qqt-dev-"):
			return true
	return false
