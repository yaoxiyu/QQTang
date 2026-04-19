class_name RoomEntryRequest
extends RefCounted

var host: String = "127.0.0.1"
var port: int = 9100
var room_id: String = ""
var map_id: String = ""
var rule_id: String = ""
var mode_id: String = ""


func to_dict() -> Dictionary:
	return {
		"host": host,
		"port": port,
		"room_id": room_id,
		"map_id": map_id,
		"rule_id": rule_id,
		"mode_id": mode_id,
	}

