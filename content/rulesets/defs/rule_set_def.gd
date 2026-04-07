extends Resource
class_name RuleSetDef

@export var rule_set_id: String = ""
@export var time_limit_sec: int = 180
@export var round_count: int = 1
@export var respawn_enabled: bool = false
@export var friendly_fire: bool = false
@export var sudden_death_enabled: bool = true
@export var item_drop_profile_id: String = ""
@export var player_explosion_profile_id: String = "player_kill_default"
@export var bubble_explosion_profile_id: String = "bubble_chain_immediate"
@export var item_explosion_profile_id: String = "item_destroy_default"
@export var breakable_block_explosion_profile_id: String = "breakable_destroy_stop"
@export var score_policy: String = "last_survivor"
