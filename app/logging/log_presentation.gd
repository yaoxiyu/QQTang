## 表现层模块日志
class_name LogPresentation
extends RefCounted

static func debug(message: String, file: String = "", line: int = 0, tag: String = "") -> void:
	LogManager.debug(LogLevelConstants.Type.PRESENTATION, message, file, line, tag)

static func info(message: String, file: String = "", line: int = 0, tag: String = "") -> void:
	LogManager.info(LogLevelConstants.Type.PRESENTATION, message, file, line, tag)

static func warn(message: String, file: String = "", line: int = 0, tag: String = "") -> void:
	LogManager.warn(LogLevelConstants.Type.PRESENTATION, message, file, line, tag)

static func error(message: String, file: String = "", line: int = 0, tag: String = "") -> void:
	LogManager.error(LogLevelConstants.Type.PRESENTATION, message, file, line, tag)

static func fatal(message: String, file: String = "", line: int = 0, tag: String = "") -> void:
	LogManager.fatal(LogLevelConstants.Type.PRESENTATION, message, file, line, tag)
