class_name RoomEntryContext
extends RefCounted

var entry_kind: String = ""
var room_kind: String = ""
var topology: String = ""
var server_host: String = ""
var server_port: int = 0
var target_room_id: String = ""
var room_display_name: String = ""
var return_target: String = ""
var should_auto_connect: bool = false
var should_auto_join: bool = false

# Phase17: Resume flow fields
var use_resume_flow: bool = false
var reconnect_member_id: String = ""
var reconnect_token: String = ""
var reconnect_match_id: String = ""


func to_dict() -> Dictionary:
	return {
		"entry_kind": entry_kind,
		"room_kind": room_kind,
		"topology": topology,
		"server_host": server_host,
		"server_port": server_port,
		"target_room_id": target_room_id,
		"room_display_name": room_display_name,
		"return_target": return_target,
		"should_auto_connect": should_auto_connect,
		"should_auto_join": should_auto_join,
		"use_resume_flow": use_resume_flow,
		"reconnect_member_id": reconnect_member_id,
		"reconnect_token": reconnect_token,
		"reconnect_match_id": reconnect_match_id,
	}


func duplicate_deep() -> RoomEntryContext:
	var copy := RoomEntryContext.new()
	copy.entry_kind = entry_kind
	copy.room_kind = room_kind
	copy.topology = topology
	copy.server_host = server_host
	copy.server_port = server_port
	copy.target_room_id = target_room_id
	copy.room_display_name = room_display_name
	copy.return_target = return_target
	copy.should_auto_connect = should_auto_connect
	copy.should_auto_join = should_auto_join
	# Phase17: Resume flow fields
	copy.use_resume_flow = use_resume_flow
	copy.reconnect_member_id = reconnect_member_id
	copy.reconnect_token = reconnect_token
	copy.reconnect_match_id = reconnect_match_id
	return copy
