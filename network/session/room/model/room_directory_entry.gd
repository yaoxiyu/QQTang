class_name RoomDirectoryEntry
extends RefCounted

var room_id: String = ""
var room_display_name: String = ""
var room_kind: String = ""
var owner_peer_id: int = 0
var owner_name: String = ""
var selected_map_id: String = ""
var rule_set_id: String = ""
var mode_id: String = ""
var member_count: int = 0
var max_players: int = 0
var match_active: bool = false
var joinable: bool = false


func to_dict() -> Dictionary:
	return {
		"room_id": room_id,
		"room_display_name": room_display_name,
		"room_kind": room_kind,
		"owner_peer_id": owner_peer_id,
		"owner_name": owner_name,
		"selected_map_id": selected_map_id,
		"rule_set_id": rule_set_id,
		"mode_id": mode_id,
		"member_count": member_count,
		"max_players": max_players,
		"match_active": match_active,
		"joinable": joinable,
	}


static func from_dict(data: Dictionary) -> RoomDirectoryEntry:
	var entry := RoomDirectoryEntry.new()
	entry.room_id = String(data.get("room_id", ""))
	entry.room_display_name = String(data.get("room_display_name", ""))
	entry.room_kind = String(data.get("room_kind", ""))
	entry.owner_peer_id = int(data.get("owner_peer_id", 0))
	entry.owner_name = String(data.get("owner_name", ""))
	entry.selected_map_id = String(data.get("selected_map_id", ""))
	entry.rule_set_id = String(data.get("rule_set_id", ""))
	entry.mode_id = String(data.get("mode_id", ""))
	entry.member_count = int(data.get("member_count", 0))
	entry.max_players = int(data.get("max_players", 0))
	entry.match_active = bool(data.get("match_active", false))
	entry.joinable = bool(data.get("joinable", false))
	return entry


func duplicate_deep() -> RoomDirectoryEntry:
	return RoomDirectoryEntry.from_dict(to_dict())
