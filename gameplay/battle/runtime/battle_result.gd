class_name BattleResult
extends RefCounted

const RuleSetCatalog = preload("res://content/rulesets/catalog/rule_set_catalog.gd")

var winner_peer_ids: Array[int] = []
var winner_team_ids: Array[int] = []
var eliminated_order: Array[int] = []
var finish_reason: String = ""
var finish_tick: int = 0
var local_peer_id: int = -1
var local_team_id: int = -1
var team_scores: Dictionary = {}
var player_scores: Dictionary = {}
var local_outcome: String = ""
var score_policy: String = ""


func to_dict() -> Dictionary:
	return {
		"winner_peer_ids": winner_peer_ids.duplicate(),
		"winner_team_ids": winner_team_ids.duplicate(),
		"eliminated_order": eliminated_order.duplicate(),
		"finish_reason": finish_reason,
		"finish_tick": finish_tick,
		"local_peer_id": local_peer_id,
		"local_team_id": local_team_id,
		"team_scores": team_scores.duplicate(true),
		"player_scores": player_scores.duplicate(true),
		"local_outcome": local_outcome,
		"score_policy": score_policy,
	}


static func from_dict(data: Dictionary) -> BattleResult:
	var result := BattleResult.new()
	result.winner_peer_ids.assign(data.get("winner_peer_ids", []))
	result.winner_team_ids.assign(data.get("winner_team_ids", []))
	result.eliminated_order.assign(data.get("eliminated_order", []))
	result.finish_reason = String(data.get("finish_reason", ""))
	result.finish_tick = int(data.get("finish_tick", 0))
	result.local_peer_id = int(data.get("local_peer_id", -1))
	result.local_team_id = int(data.get("local_team_id", -1))
	result.team_scores = _coerce_dictionary(data.get("team_scores", {}))
	result.player_scores = _coerce_dictionary(data.get("player_scores", {}))
	result.local_outcome = String(data.get("local_outcome", ""))
	result.score_policy = String(data.get("score_policy", ""))
	return result


static func from_authoritative_state(world: SimWorld, start_config: BattleStartConfig, _local_peer_id: int = -1) -> BattleResult:
	var result := BattleResult.new()
	result.local_peer_id = _local_peer_id
	if world == null:
		return result

	result.finish_tick = world.state.match_state.tick
	result.finish_reason = _finish_reason_from_match_state(world.state.match_state.ended_reason)
	result.score_policy = _resolve_score_policy(world, start_config)

	var slot_to_peer: Dictionary = {}
	var slot_to_team: Dictionary = {}
	if start_config != null:
		for player_entry in start_config.players:
			var slot_index := int(player_entry.get("slot_index", -1))
			var peer_id := int(player_entry.get("peer_id", -1))
			var team_id := int(player_entry.get("team_id", -1))
			if slot_index >= 0 and peer_id >= 0:
				slot_to_peer[slot_index] = peer_id
			if slot_index >= 0 and team_id >= 0:
				slot_to_team[slot_index] = team_id

	var winner_player_id := world.state.match_state.winner_player_id
	if winner_player_id >= 0:
		var winner_player := world.state.players.get_player(winner_player_id)
		if winner_player != null:
			var winner_peer_id := int(slot_to_peer.get(winner_player.player_slot, -1))
			if winner_peer_id >= 0:
				result.winner_peer_ids.append(winner_peer_id)

	if world.state.match_state.winner_team_id >= 1:
		result.winner_team_ids.append(int(world.state.match_state.winner_team_id))

	for player_id in range(world.state.players.size()):
		var player := world.state.players.get_player(player_id)
		if player == null:
			continue
		var peer_id := int(slot_to_peer.get(player.player_slot, -1))
		if peer_id >= 0:
			result.player_scores[str(peer_id)] = int(player.score)
		if player.team_id >= 1 and not result.team_scores.has(str(player.team_id)):
			result.team_scores[str(player.team_id)] = int(world.state.mode.team_scores.get(player.team_id, 0))
		if not player.alive:
			if peer_id >= 0:
				result.eliminated_order.append(peer_id)

	if result.eliminated_order.is_empty() and start_config != null:
		for player_entry in start_config.players:
			var peer_id := int(player_entry.get("peer_id", -1))
			var slot_index := int(player_entry.get("slot_index", -1))
			var found_player := _find_player_by_slot(world, slot_index)
			if peer_id >= 0 and found_player != null and not found_player.alive:
				result.eliminated_order.append(peer_id)

	for team_id_variant in world.state.mode.team_scores.keys():
		var team_id := int(team_id_variant)
		result.team_scores[str(team_id)] = int(world.state.mode.team_scores.get(team_id_variant, 0))

	result.local_team_id = _resolve_local_team_id(start_config, slot_to_team, _local_peer_id)
	result.local_outcome = _resolve_local_outcome(result)
	return result


func duplicate_deep() -> BattleResult:
	return BattleResult.from_dict(to_dict())


func bind_local_peer_context(peer_id: int, start_config: BattleStartConfig = null) -> BattleResult:
	local_peer_id = peer_id
	if start_config != null:
		local_team_id = _resolve_local_team_id_from_config(start_config, local_peer_id)
	local_outcome = _resolve_local_outcome(self)
	return self


func is_local_victory() -> bool:
	if local_outcome == "victory":
		return true
	if local_peer_id < 0:
		return false
	return local_peer_id in winner_peer_ids


func is_local_draw() -> bool:
	return local_outcome == "draw"


static func _find_player_by_slot(world: SimWorld, slot_index: int) -> PlayerState:
	for player_id in range(world.state.players.size()):
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


static func _resolve_score_policy(world: SimWorld, start_config: BattleStartConfig) -> String:
	if start_config != null and not String(start_config.rule_set_id).is_empty():
		var rule_set := RuleSetCatalog.get_by_id(String(start_config.rule_set_id))
		if rule_set != null:
			return String(rule_set.score_policy)
	if world != null and world.config != null:
		var rule_flags : Dictionary = world.config.system_flags.get("rule_set", {})
		if rule_flags is Dictionary:
			return String(rule_flags.get("score_policy", ""))
	return ""


static func _resolve_local_team_id(start_config: BattleStartConfig, slot_to_team: Dictionary, local_peer_id: int) -> int:
	if start_config == null or local_peer_id <= 0:
		return -1
	var resolved_peer_id := int(start_config.controlled_peer_id) if int(start_config.controlled_peer_id) > 0 else local_peer_id
	for player_entry in start_config.players:
		if int(player_entry.get("peer_id", -1)) != resolved_peer_id:
			continue
		var slot_index := int(player_entry.get("slot_index", -1))
		return int(slot_to_team.get(slot_index, int(player_entry.get("team_id", -1))))
	return -1


static func _resolve_local_outcome(result: BattleResult) -> String:
	if result == null:
		return ""
	if result.local_team_id >= 1 and result.winner_team_ids.has(result.local_team_id):
		return "victory"
	if result.winner_team_ids.is_empty():
		if result.finish_reason == "time_up" or result.finish_reason == "team_eliminated" or result.finish_reason == "last_survivor":
			return "draw"
		return ""
	if result.local_team_id >= 1:
		return "defeat"
	if result.local_peer_id >= 0 and result.winner_peer_ids.has(result.local_peer_id):
		return "victory"
	if not result.winner_peer_ids.is_empty():
		return "defeat"
	return ""


static func _resolve_local_team_id_from_config(start_config: BattleStartConfig, peer_id: int) -> int:
	if start_config == null or peer_id <= 0:
		return -1
	var resolved_peer_id := int(start_config.controlled_peer_id) if int(start_config.controlled_peer_id) > 0 else peer_id
	for player_entry in start_config.players:
		if int(player_entry.get("peer_id", -1)) != resolved_peer_id:
			continue
		return int(player_entry.get("team_id", -1))
	return -1


static func _coerce_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value.duplicate(true)
	return {}
