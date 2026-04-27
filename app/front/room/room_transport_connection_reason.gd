class_name RoomTransportConnectionReason
extends RefCounted

const CONNECTED_FOR_CREATE := "connected_for_create"
const CONNECTED_FOR_JOIN := "connected_for_join"
const CONNECTED_FOR_RECOVER := "connected_for_recover"
const CONNECTED_FOR_REUSE := "connected_for_reuse"
const CONNECTED_FOR_BATTLE_RETURN := "connected_for_battle_return"
const CONNECTED_FOR_DIRECTORY := "connected_for_directory"
const UNKNOWN := "unknown"


static func is_pending_entry_reason(reason: String) -> bool:
	return reason == CONNECTED_FOR_CREATE or reason == CONNECTED_FOR_JOIN or reason == CONNECTED_FOR_RECOVER
