class_name ExplosionReactionResolver
extends RefCounted

const ExplosionHitTypes = preload("res://gameplay/simulation/explosion/explosion_hit_types.gd")
const ExplosionReactionProfileRegistry = preload("res://gameplay/simulation/explosion/explosion_reaction_profile_registry.gd")

const DEFAULT_PLAYER_PROFILE_ID := "player_kill_default"
const DEFAULT_BUBBLE_PROFILE_ID := "bubble_chain_immediate"
const DEFAULT_ITEM_PROFILE_ID := "item_destroy_default"
const DEFAULT_BREAKABLE_BLOCK_PROFILE_ID := "breakable_destroy_stop"


static func resolve_player_reaction(ctx: SimContext, player: PlayerState) -> Dictionary:
	var config: Dictionary = _get_explosion_reaction_config(ctx)
	var profile_id := String(config.get("player_profile_id", DEFAULT_PLAYER_PROFILE_ID))
	var profile: Dictionary = config.get(
		"player_profile",
		ExplosionReactionProfileRegistry.get_player_profile(profile_id)
	)
	var reaction := int(profile.get("reaction", ExplosionHitTypes.PlayerReaction.KILL))

	return {
		"profile_id": profile_id,
		"reaction": reaction,
		"should_register_hit": player != null and player.alive,
		"should_stop_propagation": false,
		"should_enqueue_chain": false,
		"transform_item_type": -1,
	}


static func resolve_bubble_reaction(ctx: SimContext, bubble: BubbleState) -> Dictionary:
	var config: Dictionary = _get_explosion_reaction_config(ctx)
	var profile_id := String(config.get("bubble_profile_id", DEFAULT_BUBBLE_PROFILE_ID))
	var profile: Dictionary = config.get(
		"bubble_profile",
		ExplosionReactionProfileRegistry.get_bubble_profile(profile_id)
	)
	var reaction := int(profile.get("reaction", ExplosionHitTypes.BubbleReaction.TRIGGER_IMMEDIATE_CHAIN))

	return {
		"profile_id": profile_id,
		"reaction": reaction,
		"should_register_hit": bubble != null and bubble.alive,
		"should_stop_propagation": false,
		"should_enqueue_chain": reaction == ExplosionHitTypes.BubbleReaction.TRIGGER_IMMEDIATE_CHAIN,
		"transform_item_type": -1,
	}


static func resolve_item_reaction(ctx: SimContext, item: ItemState) -> Dictionary:
	var config: Dictionary = _get_explosion_reaction_config(ctx)
	var profile_id := String(config.get("item_profile_id", DEFAULT_ITEM_PROFILE_ID))
	var profile: Dictionary = config.get(
		"item_profile",
		ExplosionReactionProfileRegistry.get_item_profile(profile_id)
	)
	var reaction := int(profile.get("reaction", ExplosionHitTypes.ItemReaction.DESTROY))
	var transform_item_type := int(profile.get("transform_item_type", -1))

	return {
		"profile_id": profile_id,
		"reaction": reaction,
		"should_register_hit": item != null and item.alive,
		"should_stop_propagation": false,
		"should_enqueue_chain": false,
		"transform_item_type": transform_item_type,
	}


static func resolve_breakable_block_reaction(ctx: SimContext, cell_x: int, cell_y: int) -> Dictionary:
	var config: Dictionary = _get_explosion_reaction_config(ctx)
	var profile_id := String(config.get("breakable_block_profile_id", DEFAULT_BREAKABLE_BLOCK_PROFILE_ID))
	var profile: Dictionary = config.get(
		"breakable_block_profile",
		ExplosionReactionProfileRegistry.get_breakable_block_profile(profile_id)
	)
	var reaction := int(profile.get("reaction", ExplosionHitTypes.BlockReaction.DESTROY_AND_STOP))
	var should_stop := reaction == ExplosionHitTypes.BlockReaction.DESTROY_AND_STOP

	return {
		"profile_id": profile_id,
		"reaction": reaction,
		"should_register_hit": _is_breakable_block_alive(ctx, cell_x, cell_y),
		"should_stop_propagation": should_stop,
		"should_enqueue_chain": false,
		"transform_item_type": -1,
	}


static func _get_explosion_reaction_config(ctx: SimContext) -> Dictionary:
	if ctx == null or ctx.config == null:
		return {}
	return ctx.config.system_flags.get("explosion_reaction", {})


static func _is_breakable_block_alive(ctx: SimContext, cell_x: int, cell_y: int) -> bool:
	if ctx == null or ctx.state == null or ctx.state.grid == null:
		return false
	if not ctx.state.grid.is_in_bounds(cell_x, cell_y):
		return false
	var static_cell = ctx.state.grid.get_static_cell(cell_x, cell_y)
	if static_cell == null:
		return false
	return static_cell.tile_type == TileConstants.TileType.BREAKABLE_BLOCK
