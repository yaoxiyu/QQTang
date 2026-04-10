class_name ExplosionHitTypes
extends RefCounted


enum TargetType {
	PLAYER,
	BUBBLE,
	ITEM,
	BREAKABLE_BLOCK
}


enum PlayerReaction {
	KILL,
	TRAP_JELLY,
	IGNORE
}


enum BubbleReaction {
	TRIGGER_IMMEDIATE_CHAIN,
	IGNORE
}


enum ItemReaction {
	DESTROY,
	TRANSFORM,
	IGNORE
}


enum BlockReaction {
	DESTROY_AND_STOP,
	IGNORE
}


static func target_type_to_string(target_type: int) -> String:
	match target_type:
		TargetType.PLAYER:
			return "player"
		TargetType.BUBBLE:
			return "bubble"
		TargetType.ITEM:
			return "item"
		TargetType.BREAKABLE_BLOCK:
			return "breakable_block"
		_:
			return "unknown_target"


static func player_reaction_to_string(reaction: int) -> String:
	match reaction:
		PlayerReaction.KILL:
			return "kill"
		PlayerReaction.TRAP_JELLY:
			return "trap_jelly"
		PlayerReaction.IGNORE:
			return "ignore"
		_:
			return "unknown_player_reaction"


static func bubble_reaction_to_string(reaction: int) -> String:
	match reaction:
		BubbleReaction.TRIGGER_IMMEDIATE_CHAIN:
			return "trigger_immediate_chain"
		BubbleReaction.IGNORE:
			return "ignore"
		_:
			return "unknown_bubble_reaction"


static func item_reaction_to_string(reaction: int) -> String:
	match reaction:
		ItemReaction.DESTROY:
			return "destroy"
		ItemReaction.TRANSFORM:
			return "transform"
		ItemReaction.IGNORE:
			return "ignore"
		_:
			return "unknown_item_reaction"


static func block_reaction_to_string(reaction: int) -> String:
	match reaction:
		BlockReaction.DESTROY_AND_STOP:
			return "destroy_and_stop"
		BlockReaction.IGNORE:
			return "ignore"
		_:
			return "unknown_block_reaction"
