extends RefCounted
class_name ClassicRuleDef

static func build() -> Dictionary:
    return {
        "rule_id": "classic",
        "display_name": "经典模式",
        "version": 1,
        "description": "最后生存者获胜的经典对局规则。",
        "round_time_sec": 180,
        "starting_bomb_count": 1,
        "starting_firepower": 1,
        "starting_speed": 1,
        "allow_chain_reaction": true,
        "victory_mode": "last_survivor"
    }
