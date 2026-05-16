class_name RuntimeMessageRouter
extends Node

const LogSessionScript = preload("res://app/logging/log_session.gd")
const DEBUG_ROUTER_LOGS: bool = false

var _handlers: Dictionary = {}
var _fallback_handler: Callable = Callable()


func register_handler(message_type: String, handler: Callable) -> void:
	if message_type.is_empty():
		return
	_handlers[message_type] = handler


func set_fallback_handler(handler: Callable) -> void:
	_fallback_handler = handler


func route_messages(messages: Array) -> void:
	for message in messages:
		var message_type := _message_type(message)
		if DEBUG_ROUTER_LOGS:
			LogSessionScript.debug("route %s" % message_type, "", 0, "session.message_router")
		if _handlers.has(message_type):
			var handler: Callable = _handlers[message_type]
			if handler.is_valid():
				handler.call(message)
		elif _fallback_handler.is_valid():
			_fallback_handler.call(message)


func _message_type(message: Dictionary) -> String:
	return str(message.get("message_type", ""))
