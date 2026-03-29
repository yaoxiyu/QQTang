class_name AppRuntimeConfig
extends RefCounted

var enable_local_loop_debug_room: bool = true
var auto_create_room_on_enter: bool = true
var auto_add_remote_debug_member: bool = true


func to_dict() -> Dictionary:
	return {
		"enable_local_loop_debug_room": enable_local_loop_debug_room,
		"auto_create_room_on_enter": auto_create_room_on_enter,
		"auto_add_remote_debug_member": auto_add_remote_debug_member,
	}
