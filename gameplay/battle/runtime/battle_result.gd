class_name BattleResult
extends RefCounted

var winner_peer_ids: Array[int] = []
var eliminated_order: Array[int] = []
var finish_reason: String = ""
var finish_tick: int = 0
var local_peer_id: int = -1


func to_dict() -> Dictionary:
	return {
		"winner_peer_ids": winner_peer_ids.duplicate(),
		"eliminated_order": eliminated_order.duplicate(),
		"finish_reason": finish_reason,
		"finish_tick": finish_tick,
		"local_peer_id": local_peer_id,
	}


static func from_dict(data: Dictionary) -> BattleResult:
	var result := BattleResult.new()
	result.winner_peer_ids.assign(data.get("winner_peer_ids", []))
	result.eliminated_order.assign(data.get("eliminated_order", []))
	result.finish_reason = String(data.get("finish_reason", ""))
	result.finish_tick = int(data.get("finish_tick", 0))
	result.local_peer_id = int(data.get("local_peer_id", -1))
	return result


static func from_authoritative_state(world: SimWorld, start_config: BattleStartConfig, _local_peer_id: int = -1) -> BattleResult:
	var result := BattleResult.new()
	result.local_peer_id = _local_peer_id
	if world == null:
		return result

	result.finish_tick = world.state.match_state.tick
	result.finish_reason = _finish_reason_from_match_state(world.state.match_state.ended_reason)

	var slot_to_peer: Dictionary = {}
	if start_config != null:
		for player_entry in start_config.players:
			var slot_index := int(player_entry.get("slot_index", -1))
			var peer_id := int(player_entry.get("peer_id", -1))
			if slot_index >= 0 and peer_id >= 0:
				slot_to_peer[slot_index] = peer_id

	var winner_player_id := world.state.match_state.winner_player_id
	if winner_player_id >= 0:
		var winner_player := world.state.players.get_player(winner_player_id)
		if winner_player != null:
			var winner_peer_id := int(slot_to_peer.get(winner_player.player_slot, -1))
			if winner_peer_id >= 0:
				result.winner_peer_ids.append(winner_peer_id)

	for player_id in world.state.players.active_ids:
		var player := world.state.players.get_player(player_id)
		if player == null:
			continue
		if not player.alive:
			var peer_id := int(slot_to_peer.get(player.player_slot, -1))
			if peer_id >= 0:
				result.eliminated_order.append(peer_id)

	if result.eliminated_order.is_empty() and start_config != null:
		for player_entry in start_config.players:
			var peer_id := int(player_entry.get("peer_id", -1))
			var slot_index := int(player_entry.get("slot_index", -1))
			var found_player := _find_player_by_slot(world, slot_index)
			if peer_id >= 0 and found_player != null and not found_player.alive:
				result.eliminated_order.append(peer_id)

	return result


func duplicate_deep() -> BattleResult:
	return BattleResult.from_dict(to_dict())


func bind_local_peer_context(peer_id: int) -> BattleResult:
	local_peer_id = peer_id
	return self


func is_local_victory() -> bool:
	if local_peer_id < 0:
		return false
	return local_peer_id in winner_peer_ids


static func _find_player_by_slot(world: SimWorld, slot_index: int) -> PlayerState:
	for player_id in world.state.players.active_ids:
		var player := world.state.players.get_player(player_id)
		if player != null and player.player_slot == slot_index:
			return player
	return null


static func _finish_reason_from_match_state(ended_reason: int) -> String:
	match ended_reason:
		MatchState.EndReason.LAST_SURVIVOR:
			return "last_survivor"
		MatchState.EndReason.TEAM_ELIMINATED:
			return "team_eliminated"
		MatchState.EndReason.TIME_UP:
			return "time_up"
		MatchState.EndReason.MODE_OBJECTIVE:
			return "mode_objective"
		MatchState.EndReason.FORCE_END:
			return "force_end"
		_:
			return "match_ended"
