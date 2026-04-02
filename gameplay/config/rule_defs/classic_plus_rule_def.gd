extends RefCounted
class_name ClassicPlusRuleDef


static func build() -> Dictionary:
	return {
		"rule_id": "classic_plus",
		"display_name": "经典强化",
		"version": 1,
		"description": "在经典模式基础上提供更丰富掉落与更长局时的强化规则。",
		"round_time_sec": 210,
		"starting_bomb_count": 1,
		"starting_firepower": 1,
		"starting_speed": 1,
		"allow_chain_reaction": true,
		"victory_mode": "last_survivor",
		"item_drop_profile": "classic_plus_items",
		"gameplay_params": {
			"score_mode": "survival",
			"sudden_death_enabled": false,
			"respawn_enabled": false,
			"item_drop_profile_override": "classic_plus_items",
			"max_round_count": 1,
		},
	}
