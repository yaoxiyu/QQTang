class_name GameServicePartyQueueModels
extends RefCounted


static func build_member(
	account_id: String,
	profile_id: String,
	device_session_id: String,
	seat_index: int
) -> Dictionary:
	return {
		"account_id": account_id,
		"profile_id": profile_id,
		"device_session_id": device_session_id,
		"seat_index": seat_index,
	}


static func build_enter_request(
	party_room_id: String,
	queue_type: String,
	match_format_id: String,
	selected_mode_ids: Array[String],
	members: Array[Dictionary]
) -> Dictionary:
	return {
		"party_room_id": party_room_id,
		"queue_type": queue_type,
		"match_format_id": match_format_id,
		"selected_mode_ids": selected_mode_ids.duplicate(),
		"members": _duplicate_member_array(members),
	}


static func build_cancel_request(party_room_id: String, queue_entry_id: String) -> Dictionary:
	return {
		"party_room_id": party_room_id,
		"queue_entry_id": queue_entry_id,
	}


static func _duplicate_member_array(members: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for member in members:
		result.append(member.duplicate(true))
	return result
