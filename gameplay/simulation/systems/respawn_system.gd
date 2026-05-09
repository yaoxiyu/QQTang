class_name RespawnSystem
extends ISimSystem

const PlayerLocator = preload("res://gameplay/simulation/movement/player_locator.gd")
const BubblePassPhaseHelper = preload("res://gameplay/simulation/movement/bubble_pass_phase_helper.gd")


func get_name() -> StringName:
	return "RespawnSystem"


func execute(ctx: SimContext) -> void:
	for player_id in range(ctx.state.players.size()):
		var player := ctx.state.players.get_player(player_id)
		if player == null:
			continue
		if player.life_state != PlayerState.LifeState.REVIVING:
			continue

		player.respawn_ticks -= 1
		if player.respawn_ticks > 0:
			ctx.state.players.update_player(player)
			continue

		_revive_player(ctx, player)


func _revive_player(ctx: SimContext, player: PlayerState) -> void:
	var spawn_cell := _resolve_spawn_cell(ctx, player.player_slot)
	player.alive = true
	player.life_state = PlayerState.LifeState.NORMAL
	player.respawn_ticks = 0
	player.cell_x = spawn_cell.x
	player.cell_y = spawn_cell.y
	player.offset_x = 0
	player.offset_y = 0
	player.move_state = PlayerState.MoveState.IDLE
	player.move_remainder_units = 0
	player.last_non_zero_move_x = 0
	player.last_non_zero_move_y = 0
	player.trap_bubble_id = -1
	player.last_damage_from_player_id = -1
	player.invincible_ticks = _get_respawn_invincible_ticks(ctx)
	player.bomb_available = player.bomb_capacity
	ctx.state.players.update_player(player)

	# 清理所有活着泡泡上残留的 phase 条目，避免幽灵记录污染 checksum。
	# BubblePhaseAdvancer 会在玩家移动时按当前位置按需重建条目。
	_clear_player_bubble_phases(ctx, player.entity_id)

	_add_player_to_active_ids(ctx, player.entity_id)
	_add_player_to_live_indexes(ctx, player.entity_id, PlayerLocator.get_foot_cell(player))

	var revived_event := SimEvent.new(ctx.tick, SimEvent.EventType.PLAYER_REVIVED)
	revived_event.payload = {
		"player_id": player.entity_id,
		"cell_x": spawn_cell.x,
		"cell_y": spawn_cell.y,
		"revive_type": "respawn",
	}
	ctx.events.push(revived_event)


func _resolve_spawn_cell(ctx: SimContext, player_slot: int) -> Vector2i:
	var spawn_assignments: Array[Dictionary] = _get_spawn_assignments(ctx)
	for assignment in spawn_assignments:
		if int(assignment.get("slot_index", -1)) != player_slot:
			continue
		return Vector2i(
			int(assignment.get("spawn_cell_x", 1)),
			int(assignment.get("spawn_cell_y", 1))
		)
	return Vector2i(1, 1)


func _add_player_to_active_ids(ctx: SimContext, player_id: int) -> void:
	if not ctx.state.players.active_ids.has(player_id):
		ctx.state.players.active_ids.append(player_id)
		ctx.state.players.active_ids.sort()


func _add_player_to_live_indexes(ctx: SimContext, player_id: int, foot_cell: Vector2i) -> void:
	if not ctx.state.indexes.living_player_ids.has(player_id):
		ctx.state.indexes.living_player_ids.append(player_id)
		ctx.state.indexes.living_player_ids.sort()

	if not ctx.state.grid.is_in_bounds(foot_cell.x, foot_cell.y):
		return

	var cell_idx := ctx.state.grid.to_cell_index(foot_cell.x, foot_cell.y)
	if cell_idx < 0 or cell_idx >= ctx.state.indexes.players_by_cell.size():
		return

	var players_in_cell: Array = ctx.state.indexes.players_by_cell[cell_idx]
	if not players_in_cell.has(player_id):
		players_in_cell.append(player_id)


func _get_respawn_invincible_ticks(ctx: SimContext) -> int:
	var rule_flags: Dictionary = _get_rule_flags(ctx)
	var invincible_sec := int(rule_flags.get("respawn_invincible_sec", 0))
	if invincible_sec <= 0:
		return 0
	return invincible_sec * max(ctx.config.tick_rate, 1)


func _get_spawn_assignments(ctx: SimContext) -> Array[Dictionary]:
	var assignments : Array = ctx.config.system_flags.get("spawn_assignments", [])
	var result: Array[Dictionary] = []
	if assignments is Array:
		for entry in assignments:
			if entry is Dictionary:
				result.append(entry)
	return result


func _get_rule_flags(ctx: SimContext) -> Dictionary:
	var rule_flags : Dictionary = ctx.config.system_flags.get("rule_set", {})
	if rule_flags is Dictionary:
		return rule_flags
	return {}


func _clear_player_bubble_phases(ctx: SimContext, player_id: int) -> void:
	for bubble_id in ctx.state.bubbles.active_ids:
		var bubble := ctx.state.bubbles.get_bubble(bubble_id)
		if bubble == null or not bubble.alive:
			continue
		if BubblePassPhaseHelper.remove_phase(bubble, player_id):
			ctx.state.bubbles.update_bubble(bubble)
