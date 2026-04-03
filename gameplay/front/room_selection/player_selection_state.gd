class_name PlayerSelectionState
extends RefCounted

var peer_id: int = -1
var character_id: String = ""
var bubble_style_id: String = ""
var ready: bool = false


func to_dictionary() -> Dictionary:
	return {
		"peer_id": peer_id,
		"character_id": character_id,
		"bubble_style_id": bubble_style_id,
		"ready": ready,
	}
