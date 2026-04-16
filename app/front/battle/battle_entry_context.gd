class_name BattleEntryContext
extends RefCounted

## Phase23: Data object holding all info needed to enter a battle_ds instance.
## Built from authoritative RoomSnapshot Phase23 fields after allocation is ready.

var assignment_id: String = ""
var battle_id: String = ""
var match_id: String = ""
var map_id: String = ""
var rule_set_id: String = ""
var mode_id: String = ""
var battle_server_host: String = ""
var battle_server_port: int = 0
var room_return_policy: String = "return_to_source_room"

# Populated after battle ticket is acquired
var battle_ticket: String = ""
var battle_ticket_id: String = ""

# Source room info for return-to-room flow
var source_room_id: String = ""
var source_room_kind: String = ""
var source_server_host: String = ""
var source_server_port: int = 0


func is_valid() -> bool:
	return not battle_id.is_empty() \
		and not battle_server_host.is_empty() \
		and battle_server_port > 0


func to_dict() -> Dictionary:
	return {
		"assignment_id": assignment_id,
		"battle_id": battle_id,
		"match_id": match_id,
		"map_id": map_id,
		"rule_set_id": rule_set_id,
		"mode_id": mode_id,
		"battle_server_host": battle_server_host,
		"battle_server_port": battle_server_port,
		"room_return_policy": room_return_policy,
		"battle_ticket": battle_ticket,
		"battle_ticket_id": battle_ticket_id,
		"source_room_id": source_room_id,
		"source_room_kind": source_room_kind,
		"source_server_host": source_server_host,
		"source_server_port": source_server_port,
	}


static func from_dict(data: Dictionary) -> BattleEntryContext:
	var ctx := BattleEntryContext.new()
	ctx.assignment_id = String(data.get("assignment_id", ""))
	ctx.battle_id = String(data.get("battle_id", ""))
	ctx.match_id = String(data.get("match_id", ""))
	ctx.map_id = String(data.get("map_id", ""))
	ctx.rule_set_id = String(data.get("rule_set_id", ""))
	ctx.mode_id = String(data.get("mode_id", ""))
	ctx.battle_server_host = String(data.get("battle_server_host", ""))
	ctx.battle_server_port = int(data.get("battle_server_port", 0))
	ctx.room_return_policy = String(data.get("room_return_policy", "return_to_source_room"))
	ctx.battle_ticket = String(data.get("battle_ticket", ""))
	ctx.battle_ticket_id = String(data.get("battle_ticket_id", ""))
	ctx.source_room_id = String(data.get("source_room_id", ""))
	ctx.source_room_kind = String(data.get("source_room_kind", ""))
	ctx.source_server_host = String(data.get("source_server_host", ""))
	ctx.source_server_port = int(data.get("source_server_port", 0))
	return ctx


func duplicate_deep() -> BattleEntryContext:
	return BattleEntryContext.from_dict(to_dict())
