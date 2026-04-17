extends RefCounted


static func on_network_error_routed(runtime: Node, payload: Dictionary) -> void:
	if runtime == null:
		return
	runtime.last_runtime_error = payload.duplicate(true)
	runtime._last_runtime_error_code = String(runtime.last_runtime_error.get("error_code", ""))
	runtime._last_runtime_error_message = String(runtime.last_runtime_error.get("user_message", runtime.last_runtime_error.get("message", "")))
	if not runtime._last_runtime_error_code.is_empty() or not runtime._last_runtime_error_message.is_empty():
		runtime.runtime_error.emit(runtime._last_runtime_error_code, runtime._last_runtime_error_message)


static func on_client_runtime_battle_message_received(runtime: Node, message: Dictionary) -> void:
	if runtime == null:
		return
	if runtime.battle_session_adapter != null and runtime.battle_session_adapter.has_method("ingest_dedicated_server_message"):
		runtime.battle_session_adapter.ingest_dedicated_server_message(message)


static func on_client_runtime_transport_connected(runtime: Node) -> void:
	if runtime == null:
		return
	if runtime.battle_session_adapter != null and runtime.battle_session_adapter.has_method("notify_dedicated_server_transport_connected"):
		runtime.battle_session_adapter.notify_dedicated_server_transport_connected()


static func on_client_runtime_transport_disconnected(runtime: Node) -> void:
	if runtime == null:
		return
	if runtime.battle_session_adapter != null and runtime.battle_session_adapter.has_method("notify_dedicated_server_transport_disconnected"):
		runtime.battle_session_adapter.notify_dedicated_server_transport_disconnected()


static func on_client_runtime_room_error(runtime: Node, error_code: String, user_message: String) -> void:
	if runtime == null:
		return
	if runtime.battle_session_adapter != null and runtime.battle_session_adapter.has_method("notify_dedicated_server_transport_error"):
		runtime.battle_session_adapter.notify_dedicated_server_transport_error(error_code, user_message)
