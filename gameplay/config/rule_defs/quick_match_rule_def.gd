extends RefCounted
class_name QuickMatchRuleDef


static func build() -> Dictionary:
	return {
		"rule_id": "quick_match",
		"display_name": "快速对局",
		"version": 1,
		"description": "更短局时与更积极掉落节奏的快速规则，适合联调与短局体验。",
		"round_time_sec": 120,
		"starting_bomb_count": 1,
		"starting_firepower": 2,
		"starting_speed": 2,
		"allow_chain_reaction": true,
		"victory_mode": "last_survivor",
		"item_drop_profile": "quick_match_items",
		"gameplay_params": {
			"score_mode": "survival",
			"sudden_death_enabled": false,
			"respawn_enabled": false,
			"item_drop_profile_override": "quick_match_items",
			"max_round_count": 1,
		},
	}
