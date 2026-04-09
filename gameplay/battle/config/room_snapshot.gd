class_name RoomSnapshot
extends RefCounted

var room_id: String = ""
var room_kind: String = ""
var topology: String = ""
var owner_peer_id: int = 0
var members: Array[RoomMemberState] = []
var room_display_name: String = ""
var selected_map_id: String = ""
var rule_set_id: String = ""
var mode_id: String = ""
var min_start_players: int = 2
var all_ready: bool = false
var max_players: int = 0
var match_active: bool = false


func to_dict() -> Dictionary:
	var member_dicts: Array[Dictionary] = []
	for member in members:
		if member == null:
			continue
		member_dicts.append(member.to_dict())

	return {
		"room_id": room_id,
		"room_kind": room_kind,
		"topology": topology,
		"owner_peer_id": owner_peer_id,
		"members": member_dicts,
		"room_display_name": room_display_name,
		"selected_map_id": selected_map_id,
		"rule_set_id": rule_set_id,
		"mode_id": mode_id,
		"min_start_players": min_start_players,
		"all_ready": all_ready,
		"max_players": max_players,
		"match_active": match_active,
	}


static func from_dict(data: Dictionary) -> RoomSnapshot:
	var snapshot := RoomSnapshot.new()
	snapshot.room_id = String(data.get("room_id", ""))
	snapshot.room_kind = String(data.get("room_kind", ""))
	snapshot.topology = String(data.get("topology", ""))
	snapshot.owner_peer_id = int(data.get("owner_peer_id", 0))
	snapshot.room_display_name = String(data.get("room_display_name", ""))
	snapshot.selected_map_id = String(data.get("selected_map_id", ""))
	snapshot.rule_set_id = String(data.get("rule_set_id", ""))
	snapshot.mode_id = String(data.get("mode_id", ""))
	snapshot.min_start_players = int(data.get("min_start_players", 2))
	snapshot.all_ready = bool(data.get("all_ready", false))
	snapshot.max_players = int(data.get("max_players", 0))
	snapshot.match_active = bool(data.get("match_active", false))

	var member_entries: Array = data.get("members", [])
	for entry in member_entries:
		if entry is Dictionary:
			snapshot.members.append(RoomMemberState.from_dict(entry))

	return snapshot


func duplicate_deep() -> RoomSnapshot:
	return RoomSnapshot.from_dict(to_dict())


func sorted_members() -> Array[RoomMemberState]:
	var copied: Array[RoomMemberState] = []
	for member in members:
		if member != null:
			copied.append(member.duplicate_deep())

	copied.sort_custom(func(a: RoomMemberState, b: RoomMemberState) -> bool:
		if a.slot_index == b.slot_index:
			return a.peer_id < b.peer_id
		return a.slot_index < b.slot_index
	)
	return copied


func member_count() -> int:
	return members.size()


func has_member(peer_id: int) -> bool:
	for member in members:
		if member != null and member.peer_id == peer_id:
			return true
	return false
