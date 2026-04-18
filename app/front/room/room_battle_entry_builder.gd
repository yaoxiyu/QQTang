extends RefCounted

const BattleEntryContextScript = preload("res://app/front/battle/battle_entry_context.gd")


static func build(snapshot: RoomSnapshot, room_entry_context: RoomEntryContext = null):
	if snapshot == null:
		return null
	if not snapshot.battle_entry_ready:
		return null
	if snapshot.current_assignment_id.is_empty() or snapshot.current_battle_id.is_empty():
		return null
	if snapshot.battle_server_host.is_empty() or snapshot.battle_server_port <= 0:
		return null

	var ctx := BattleEntryContextScript.new()
	ctx.assignment_id = snapshot.current_assignment_id
	ctx.battle_id = snapshot.current_battle_id
	ctx.match_id = snapshot.current_match_id
	ctx.map_id = snapshot.selected_map_id
	ctx.rule_set_id = snapshot.rule_set_id
	ctx.mode_id = snapshot.mode_id
	ctx.battle_server_host = snapshot.battle_server_host
	ctx.battle_server_port = snapshot.battle_server_port
	ctx.room_return_policy = snapshot.room_return_policy
	ctx.source_room_id = snapshot.room_id
	ctx.source_room_kind = snapshot.room_kind
	if room_entry_context != null:
		ctx.source_server_host = room_entry_context.server_host
		ctx.source_server_port = room_entry_context.server_port
	return ctx
