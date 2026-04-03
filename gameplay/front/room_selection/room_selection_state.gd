class_name RoomSelectionState
extends RefCounted

var mode_id: String = ""
var map_id: String = ""
var rule_set_id: String = ""
var players: Dictionary = {}


func ensure_player(peer_id: int) -> Dictionary:
	if not players.has(peer_id):
		players[peer_id] = {
			"peer_id": peer_id,
			"character_id": "",
			"bubble_style_id": "",
			"ready": false,
		}
	return players[peer_id]
