class_name RoomErrorMapper
extends RefCounted

const DEFAULT_MESSAGE := "房间操作失败"


static func to_front_error(error_code: String, fallback_message: String = "") -> Dictionary:
	var code := String(error_code).strip_edges()
	var message := String(fallback_message).strip_edges()
	if message.is_empty():
		message = _default_message_for(code)
	return {
		"ok": false,
		"error_code": code if not code.is_empty() else "ROOM_ERROR",
		"message": message,
		"user_message": message,
	}


static func _default_message_for(error_code: String) -> String:
	match String(error_code):
		"APP_RUNTIME_MISSING":
			return "运行时尚未初始化"
		"ROOM_GATEWAY_MISSING":
			return "房间网络网关不可用"
		"ROOM_CONNECTION_PENDING":
			return "正在连接房间，请稍后"
		"ROOM_NOT_CONNECTED":
			return "尚未连接房间"
		"ROOM_QUEUE_FAILED":
			return "进入匹配队列失败"
		"ROOM_ENTRY_CONTEXT_MISSING":
			return "房间入口上下文为空"
		"ROOM_ID_MISSING":
			return "房间 ID 为空"
		"BATTLE_ENTRY_MISSING":
			return "战斗入口数据为空"
		_:
			return DEFAULT_MESSAGE
