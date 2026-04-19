package domain

import "strings"

type RoomKindCategory int

const (
	RoomKindUnknown RoomKindCategory = iota
	RoomKindCustom
	RoomKindMatch
	RoomKindRanked
)

func ParseRoomKindCategory(roomKind string) RoomKindCategory {
	switch strings.TrimSpace(strings.ToLower(roomKind)) {
	case "custom_room", "private_room", "public_room":
		return RoomKindCustom
	case "casual_match_room":
		return RoomKindMatch
	case "ranked_match_room":
		return RoomKindRanked
	default:
		return RoomKindUnknown
	}
}

