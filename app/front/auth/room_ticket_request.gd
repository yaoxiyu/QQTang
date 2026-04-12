class_name RoomTicketRequest
extends RefCounted

var purpose: String = ""
var room_id: String = ""
var room_kind: String = ""
var requested_match_id: String = ""
var selected_character_id: String = ""
var selected_character_skin_id: String = ""
var selected_bubble_style_id: String = ""
var selected_bubble_skin_id: String = ""


func to_dict() -> Dictionary:
	return {
		"purpose": purpose,
		"room_id": room_id,
		"room_kind": room_kind,
		"requested_match_id": requested_match_id,
		"selected_character_id": selected_character_id,
		"selected_character_skin_id": selected_character_skin_id,
		"selected_bubble_style_id": selected_bubble_style_id,
		"selected_bubble_skin_id": selected_bubble_skin_id,
	}
