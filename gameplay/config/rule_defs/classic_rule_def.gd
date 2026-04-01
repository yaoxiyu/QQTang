extends RefCounted
class_name ClassicRuleDef

static func build() -> Dictionary:
    return {
        "rule_id": "classic",
        "display_name": "经典模式",
        "round_time_sec": 180,
        "starting_bomb_count": 1,
        "starting_firepower": 1,
        "starting_speed": 1,
        "allow_chain_reaction": true,
        "victory_mode": "last_survivor"
    }
