class_name RoomMemberState
extends RefCounted

var peer_id: int = 0
var player_name: String = ""
var ready: bool = false
var slot_index: int = -1
var character_id: String = ""
var character_skin_id: String = ""
var bubble_style_id: String = ""
var bubble_skin_id: String = ""
var is_owner: bool = false
var is_local_player: bool = false
var connection_state: String = ""


func to_dict() -> Dictionary:
	return {
		"peer_id": peer_id,
		"player_name": player_name,
		"ready": ready,
		"slot_index": slot_index,
		"character_id": character_id,
		"character_skin_id": character_skin_id,
		"bubble_style_id": bubble_style_id,
		"bubble_skin_id": bubble_skin_id,
		"is_owner": is_owner,
		"is_local_player": is_local_player,
		"connection_state": connection_state,
	}


static func from_dict(data: Dictionary) -> RoomMemberState:
	var state := RoomMemberState.new()
	state.peer_id = int(data.get("peer_id", 0))
	state.player_name = String(data.get("player_name", ""))
	state.ready = bool(data.get("ready", false))
	state.slot_index = int(data.get("slot_index", -1))
	state.character_id = String(data.get("character_id", ""))
	state.character_skin_id = String(data.get("character_skin_id", ""))
	state.bubble_style_id = String(data.get("bubble_style_id", ""))
	state.bubble_skin_id = String(data.get("bubble_skin_id", ""))
	state.is_owner = bool(data.get("is_owner", false))
	state.is_local_player = bool(data.get("is_local_player", false))
	state.connection_state = String(data.get("connection_state", ""))
	return state


func duplicate_deep() -> RoomMemberState:
	return RoomMemberState.from_dict(to_dict())


func is_valid_member() -> bool:
	return peer_id > 0
