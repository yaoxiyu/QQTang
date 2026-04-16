class_name FrontRoomKind
extends RefCounted

const PRACTICE := "practice"
const PRIVATE_ROOM := "private_room"
const PUBLIC_ROOM := "public_room"
const CASUAL_MATCH_ROOM := "casual_match_room"
const RANKED_MATCH_ROOM := "ranked_match_room"
# MATCHMADE_ROOM is deprecated. Kept for migration compat only.
# New flows should NOT construct this kind. Use assignment-based battle entry instead.
const MATCHMADE_ROOM := "matchmade_room"


static func is_custom_room(room_kind: String) -> bool:
	return room_kind == PRACTICE \
		or room_kind == PRIVATE_ROOM \
		or room_kind == PUBLIC_ROOM


static func is_match_room(room_kind: String) -> bool:
	return room_kind == CASUAL_MATCH_ROOM \
		or room_kind == RANKED_MATCH_ROOM


static func is_assigned_room(room_kind: String) -> bool:
	return room_kind == MATCHMADE_ROOM
