class_name ExplosionHitSystem
extends ISimSystem

const ExplosionHitTypes = preload("res://gameplay/simulation/explosion/explosion_hit_types.gd")
const ExplosionReactionResolver = preload("res://gameplay/simulation/explosion/explosion_reaction_resolver.gd")


func get_name() -> StringName:
	return "ExplosionHitSystem"


func execute(ctx: SimContext) -> void:
	for raw_entry in ctx.scratch.explosion_hit_entries:
		if raw_entry == null:
			continue
		var hit_entry: ExplosionHitEntry = raw_entry as ExplosionHitEntry
		if hit_entry == null:
			continue

		match hit_entry.target_type:
			ExplosionHitTypes.TargetType.PLAYER:
				_process_player_hit(ctx, hit_entry)
			ExplosionHitTypes.TargetType.ITEM:
				_process_item_hit(ctx, hit_entry)
			ExplosionHitTypes.TargetType.BUBBLE:
				continue
			ExplosionHitTypes.TargetType.BREAKABLE_BLOCK:
				continue


func _process_player_hit(ctx: SimContext, hit_entry: ExplosionHitEntry) -> void:
	var player: PlayerState = ctx.state.players.get_player(hit_entry.target_entity_id)
	if player == null or not player.alive:
		return

	var reaction_result: Dictionary = ExplosionReactionResolver.resolve_player_reaction(ctx, player)
	match int(reaction_result.get("reaction", ExplosionHitTypes.PlayerReaction.KILL)):
		ExplosionHitTypes.PlayerReaction.KILL:
			player.last_damage_from_player_id = hit_entry.source_player_id
			ctx.state.players.update_player(player)
			if not ctx.scratch.players_to_kill.has(player.entity_id):
				ctx.scratch.players_to_kill.append(player.entity_id)
		ExplosionHitTypes.PlayerReaction.IGNORE:
			return


func _process_item_hit(ctx: SimContext, hit_entry: ExplosionHitEntry) -> void:
	var item: ItemState = ctx.state.items.get_item(hit_entry.target_entity_id)
	if item == null or not item.alive:
		return

	var reaction_result: Dictionary = ExplosionReactionResolver.resolve_item_reaction(ctx, item)
	match int(reaction_result.get("reaction", ExplosionHitTypes.ItemReaction.DESTROY)):
		ExplosionHitTypes.ItemReaction.DESTROY:
			_destroy_item(ctx, item)
		ExplosionHitTypes.ItemReaction.TRANSFORM:
			var transform_item_type: int = _resolve_transform_item_type(hit_entry, reaction_result)
			if transform_item_type < 0:
				return
			item.item_type = transform_item_type
			ctx.state.items.update_item(item)
		ExplosionHitTypes.ItemReaction.IGNORE:
			return


func _destroy_item(ctx: SimContext, item: ItemState) -> void:
	item.alive = false
	ctx.state.items.active_ids.erase(item.entity_id)

	if ctx.state.grid.is_in_bounds(item.cell_x, item.cell_y):
		var cell_idx := ctx.state.grid.to_cell_index(item.cell_x, item.cell_y)
		if cell_idx >= 0 and cell_idx < ctx.state.indexes.items_by_cell.size():
			if ctx.state.indexes.items_by_cell[cell_idx] == item.entity_id:
				ctx.state.indexes.items_by_cell[cell_idx] = -1

	ctx.state.items.update_item(item)


func _resolve_transform_item_type(hit_entry: ExplosionHitEntry, reaction_result: Dictionary) -> int:
	if hit_entry.target_aux_data.has("transform_item_type"):
		return int(hit_entry.target_aux_data.get("transform_item_type", -1))
	return int(reaction_result.get("transform_item_type", -1))
