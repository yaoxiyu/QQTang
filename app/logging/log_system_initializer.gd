## 日志系统初始化器
## 在 Boot 和 Dedicated Server 入口调用
class_name LogSystemInitializer
extends RefCounted

## 初始化客户端日志（在 Boot 场景调用）
static func initialize_client() -> Error:
	var err := LogManager.initialize_client()
	if err != OK:
		push_error("[LogSystemInitializer] Failed to initialize client logging: %s" % err)
		return err
	
	LogManager.info(LogLevelConstants.Type.APP, "Client log system initialized")
	return OK

## 初始化 Dedicated Server 日志（在 DS 场景调用）
static func initialize_dedicated_server() -> Error:
	var err := LogManager.initialize_dedicated_server()
	if err != OK:
		push_error("[LogSystemInitializer] Failed to initialize dedicated server logging: %s" % err)
		return err
	
	LogManager.info(LogLevelConstants.Type.APP, "Dedicated server log system initialized")
	return OK

## 关闭日志系统（在退出时调用）
static func shutdown() -> void:
	LogManager.on_exit()
