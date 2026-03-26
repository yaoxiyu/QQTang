class_name RoomMemberState
extends RefCounted

var peer_id: int = 0
var player_name: String = ""
var ready: bool = false
var slot_index: int = -1
var character_id: String = ""


func to_dict() -> Dictionary:
	return {
		"peer_id": peer_id,
		"player_name": player_name,
		"ready": ready,
		"slot_index": slot_index,
		"character_id": character_id,
	}


static func from_dict(data: Dictionary) -> RoomMemberState:
	var state := RoomMemberState.new()
	state.peer_id = int(data.get("peer_id", 0))
	state.player_name = String(data.get("player_name", ""))
	state.ready = bool(data.get("ready", false))
	state.slot_index = int(data.get("slot_index", -1))
	state.character_id = String(data.get("character_id", ""))
	return state


func duplicate_deep() -> RoomMemberState:
	return RoomMemberState.from_dict(to_dict())


func is_valid_member() -> bool:
	return peer_id > 0
