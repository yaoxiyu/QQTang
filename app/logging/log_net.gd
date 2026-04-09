## 网络模块日志
class_name LogNet
extends RefCounted

## DEBUG 级别
static func debug(message: String, file: String = "", line: int = 0, tag: String = "") -> void:
	LogManager.debug(LogLevelConstants.Type.NET, message, file, line, tag)

## INFO 级别
static func info(message: String, file: String = "", line: int = 0, tag: String = "") -> void:
	LogManager.info(LogLevelConstants.Type.NET, message, file, line, tag)

## WARN 级别
static func warn(message: String, file: String = "", line: int = 0, tag: String = "") -> void:
	LogManager.warn(LogLevelConstants.Type.NET, message, file, line, tag)

## ERROR 级别
static func error(message: String, file: String = "", line: int = 0, tag: String = "") -> void:
	LogManager.error(LogLevelConstants.Type.NET, message, file, line, tag)

## FATAL 级别
static func fatal(message: String, file: String = "", line: int = 0, tag: String = "") -> void:
	LogManager.fatal(LogLevelConstants.Type.NET, message, file, line, tag)
