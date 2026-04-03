extends Resource
class_name RuleSetDef

@export var rule_set_id: String = ""
@export var time_limit_sec: int = 180
@export var round_count: int = 1
@export var respawn_enabled: bool = false
@export var friendly_fire: bool = false
@export var sudden_death_enabled: bool = true
@export var item_drop_profile_id: String = ""
@export var score_policy: String = "last_survivor"
