## 匹配与开战模块日志
class_name LogMatch
extends RefCounted

static func debug(message: String, file: String = "", line: int = 0, tag: String = "") -> void:
	LogManager.debug(LogLevelConstants.Type.MATCH, message, file, line, tag)

static func info(message: String, file: String = "", line: int = 0, tag: String = "") -> void:
	LogManager.info(LogLevelConstants.Type.MATCH, message, file, line, tag)

static func warn(message: String, file: String = "", line: int = 0, tag: String = "") -> void:
	LogManager.warn(LogLevelConstants.Type.MATCH, message, file, line, tag)

static func error(message: String, file: String = "", line: int = 0, tag: String = "") -> void:
	LogManager.error(LogLevelConstants.Type.MATCH, message, file, line, tag)

static func fatal(message: String, file: String = "", line: int = 0, tag: String = "") -> void:
	LogManager.fatal(LogLevelConstants.Type.MATCH, message, file, line, tag)
