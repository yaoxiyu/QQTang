class_name ExplosionReactionProfileRegistry
extends RefCounted

const ExplosionHitTypes = preload("res://gameplay/simulation/explosion/explosion_hit_types.gd")

const DEFAULT_PLAYER_PROFILE_ID := "player_kill_default"
const DEFAULT_BUBBLE_PROFILE_ID := "bubble_chain_immediate"
const DEFAULT_ITEM_PROFILE_ID := "item_destroy_default"
const DEFAULT_BREAKABLE_BLOCK_PROFILE_ID := "breakable_destroy_stop"


static func get_player_profile(profile_id: String) -> Dictionary:
	match profile_id:
		"player_ignore_default":
			return {
				"profile_id": "player_ignore_default",
				"reaction": ExplosionHitTypes.PlayerReaction.IGNORE,
			}
		"player_kill_default":
			return {
				"profile_id": "player_kill_default",
				"reaction": ExplosionHitTypes.PlayerReaction.KILL,
			}
		"player_trap_default":
			return {
				"profile_id": "player_trap_default",
				"reaction": ExplosionHitTypes.PlayerReaction.TRAP_JELLY,
			}
		_:
			return get_player_profile(DEFAULT_PLAYER_PROFILE_ID)


static func get_bubble_profile(profile_id: String) -> Dictionary:
	match profile_id:
		"bubble_ignore_default":
			return {
				"profile_id": "bubble_ignore_default",
				"reaction": ExplosionHitTypes.BubbleReaction.IGNORE,
			}
		"bubble_chain_immediate":
			return {
				"profile_id": "bubble_chain_immediate",
				"reaction": ExplosionHitTypes.BubbleReaction.TRIGGER_IMMEDIATE_CHAIN,
			}
		_:
			return get_bubble_profile(DEFAULT_BUBBLE_PROFILE_ID)


static func get_item_profile(profile_id: String) -> Dictionary:
	match profile_id:
		"item_ignore_default":
			return {
				"profile_id": "item_ignore_default",
				"reaction": ExplosionHitTypes.ItemReaction.IGNORE,
				"transform_item_type": -1,
			}
		"item_transform_to_speed":
			return {
				"profile_id": "item_transform_to_speed",
				"reaction": ExplosionHitTypes.ItemReaction.TRANSFORM,
				"transform_item_type": 3,
			}
		"item_destroy_default":
			return {
				"profile_id": "item_destroy_default",
				"reaction": ExplosionHitTypes.ItemReaction.DESTROY,
				"transform_item_type": -1,
			}
		_:
			return get_item_profile(DEFAULT_ITEM_PROFILE_ID)


static func get_breakable_block_profile(profile_id: String) -> Dictionary:
	match profile_id:
		"breakable_ignore_default":
			return {
				"profile_id": "breakable_ignore_default",
				"reaction": ExplosionHitTypes.BlockReaction.IGNORE,
			}
		"breakable_destroy_stop":
			return {
				"profile_id": "breakable_destroy_stop",
				"reaction": ExplosionHitTypes.BlockReaction.DESTROY_AND_STOP,
			}
		_:
			return get_breakable_block_profile(DEFAULT_BREAKABLE_BLOCK_PROFILE_ID)
