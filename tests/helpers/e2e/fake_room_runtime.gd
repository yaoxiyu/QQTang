extends Node

class_name E2EFakeRoomRuntime

var state = null
var match_service = null

func _init(p_state, p_match_service) -> void:
	state = p_state
	match_service = p_match_service

func get_room_state():
	return state

func get_match_service():
	return match_service
