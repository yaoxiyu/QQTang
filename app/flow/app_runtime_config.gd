class_name AppRuntimeConfig
extends RefCounted

const ClientConnectionConfigScript = preload("res://network/runtime/client_connection_config.gd")
const ClientLaunchModeScript = preload("res://network/runtime/client_launch_mode.gd")

var enable_local_loop_debug_room: bool = false
var auto_create_room_on_enter: bool = false
var auto_add_remote_debug_member: bool = false
var enable_pass_through_auth_fallback: bool = false
var launch_mode: int = ClientLaunchModeScript.Value.LOCAL_SINGLEPLAYER
var transport_debug_enabled: bool = false
var client_connection: ClientConnectionConfig = ClientConnectionConfigScript.new()


func to_dict() -> Dictionary:
	return {
		"enable_local_loop_debug_room": enable_local_loop_debug_room,
		"auto_create_room_on_enter": auto_create_room_on_enter,
		"auto_add_remote_debug_member": auto_add_remote_debug_member,
		"enable_pass_through_auth_fallback": enable_pass_through_auth_fallback,
		"launch_mode": _launch_mode_to_string(launch_mode),
		"transport_debug_enabled": transport_debug_enabled,
		"client_connection": client_connection.to_dict() if client_connection != null else {},
	}


func _launch_mode_to_string(mode: int) -> String:
	match mode:
		ClientLaunchModeScript.Value.LOCAL_SINGLEPLAYER:
			return "LOCAL_SINGLEPLAYER"
		ClientLaunchModeScript.Value.NETWORK_CLIENT:
			return "NETWORK_CLIENT"
		ClientLaunchModeScript.Value.TRANSPORT_DEBUG:
			return "TRANSPORT_DEBUG"
		_:
			return "UNKNOWN"
