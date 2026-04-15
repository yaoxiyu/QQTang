class_name RoomEntryContext
extends RefCounted

var entry_kind: String = ""
var room_kind: String = ""
var topology: String = ""
var server_host: String = ""
var server_port: int = 0
var target_room_id: String = ""
var room_display_name: String = ""
var room_ticket: String = ""
var room_ticket_id: String = ""
var account_id: String = ""
var profile_id: String = ""
var return_target: String = ""
var should_auto_connect: bool = false
var should_auto_join: bool = false
var assignment_id: String = ""
var match_source: String = ""
var locked_map_id: String = ""
var locked_rule_set_id: String = ""
var locked_mode_id: String = ""
var assigned_team_id: int = 0
var queue_type: String = ""
var match_format_id: String = "1v1"
var selected_match_mode_ids: Array[String] = []
var is_prequeue_match_room: bool = false
var auto_ready_on_join: bool = false
var return_to_lobby_after_settlement: bool = false

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
		"room_ticket": room_ticket,
		"room_ticket_id": room_ticket_id,
		"account_id": account_id,
		"profile_id": profile_id,
		"return_target": return_target,
		"should_auto_connect": should_auto_connect,
		"should_auto_join": should_auto_join,
		"assignment_id": assignment_id,
		"match_source": match_source,
		"locked_map_id": locked_map_id,
		"locked_rule_set_id": locked_rule_set_id,
		"locked_mode_id": locked_mode_id,
		"assigned_team_id": assigned_team_id,
		"queue_type": queue_type,
		"match_format_id": match_format_id,
		"selected_match_mode_ids": selected_match_mode_ids.duplicate(),
		"is_prequeue_match_room": is_prequeue_match_room,
		"auto_ready_on_join": auto_ready_on_join,
		"return_to_lobby_after_settlement": return_to_lobby_after_settlement,
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
	copy.room_ticket = room_ticket
	copy.room_ticket_id = room_ticket_id
	copy.account_id = account_id
	copy.profile_id = profile_id
	copy.return_target = return_target
	copy.should_auto_connect = should_auto_connect
	copy.should_auto_join = should_auto_join
	copy.assignment_id = assignment_id
	copy.match_source = match_source
	copy.locked_map_id = locked_map_id
	copy.locked_rule_set_id = locked_rule_set_id
	copy.locked_mode_id = locked_mode_id
	copy.assigned_team_id = assigned_team_id
	copy.queue_type = queue_type
	copy.match_format_id = match_format_id
	copy.selected_match_mode_ids = selected_match_mode_ids.duplicate()
	copy.is_prequeue_match_room = is_prequeue_match_room
	copy.auto_ready_on_join = auto_ready_on_join
	copy.return_to_lobby_after_settlement = return_to_lobby_after_settlement
	# Phase17: Resume flow fields
	copy.use_resume_flow = use_resume_flow
	copy.reconnect_member_id = reconnect_member_id
	copy.reconnect_token = reconnect_token
	copy.reconnect_match_id = reconnect_match_id
	return copy
