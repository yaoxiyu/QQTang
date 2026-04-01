class_name NetworkErrorRouter
extends RefCounted

const NetworkErrorCodesScript = preload("res://network/runtime/network_error_codes.gd")
const RoomFlowStateScript = preload("res://network/session/runtime/room_flow_state.gd")
const SessionLifecycleStateScript = preload("res://network/session/runtime/session_lifecycle_state.gd")

var _last_error: Dictionary = {}


func route_error(
	app_runtime: Node,
	error_code: String,
	error_category: String,
	trigger_stage: String,
	user_message: String,
	log_payload: Dictionary = {},
	recovery_action: String = "",
	can_retry: bool = false
) -> Dictionary:
	var payload := {
		"error_code": error_code,
		"error_category": error_category,
		"trigger_stage": trigger_stage,
		"user_message": user_message,
		"log_payload": log_payload.duplicate(true),
		"recovery_action": recovery_action,
		"can_retry": can_retry,
	}
	_last_error = payload

	if app_runtime != null and app_runtime.has_method("_on_network_error_routed"):
		app_runtime.call("_on_network_error_routed", payload)
	elif app_runtime != null and app_runtime.has_method("push_runtime_error"):
		app_runtime.call("push_runtime_error", payload)

	var room_controller = app_runtime.room_session_controller if app_runtime != null else null
	if room_controller != null and room_controller.has_method("set_last_error"):
		room_controller.set_last_error(error_code, user_message, payload)

	if room_controller != null:
		if _should_mark_room_error(error_code):
			if room_controller.has_method("set_room_flow_state"):
				room_controller.set_room_flow_state(RoomFlowStateScript.Value.ERROR, error_code)
			if room_controller.has_method("set_session_lifecycle_state"):
				room_controller.set_session_lifecycle_state(SessionLifecycleStateScript.Value.ERROR, error_code)

	print("[NetworkError] %s %s %s %s" % [error_code, error_category, trigger_stage, JSON.stringify(log_payload)])
	return payload


func get_last_error() -> Dictionary:
	return _last_error.duplicate(true)


func clear_last_error(app_runtime: Node = null) -> void:
	_last_error = {}
	var room_controller = app_runtime.room_session_controller if app_runtime != null else null
	if room_controller != null and room_controller.has_method("clear_last_error"):
		room_controller.clear_last_error()


func _should_mark_room_error(error_code: String) -> bool:
	match error_code:
		NetworkErrorCodesScript.MATCH_CONFIG_BUILD_FAILED, NetworkErrorCodesScript.MATCH_CONFIG_VALIDATE_FAILED, NetworkErrorCodesScript.MATCH_START_RUNTIME_BOOTSTRAP_FAILED, NetworkErrorCodesScript.BATTLE_RUNTIME_ERROR, NetworkErrorCodesScript.BATTLE_DISCONNECTED, NetworkErrorCodesScript.RETURN_ROOM_FAILED, NetworkErrorCodesScript.SESSION_RECOVERY_FAILED:
			return true
		_:
			return false
