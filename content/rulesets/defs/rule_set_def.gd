extends Resource
class_name RuleSetDef

@export var rule_set_id: String = ""
@export var time_limit_sec: int = 180
@export var round_count: int = 1
@export var respawn_enabled: bool = false
@export var friendly_fire: bool = false
@export var sudden_death_enabled: bool = true
@export var item_drop_profile_id: String = ""
@export var drop_battle_backpack_on_death: bool = false
@export var player_explosion_profile_id: String = "player_kill_default"
@export var bubble_explosion_profile_id: String = "bubble_chain_immediate"
@export var item_explosion_profile_id: String = "item_destroy_default"
@export var breakable_block_explosion_profile_id: String = "breakable_destroy_stop"
@export var show_score: bool = false
@export var can_revive: bool = false
@export var score_policy: String = "last_survivor"
@export var player_down_policy: String = "kill"
@export var rescue_touch_enabled: bool = false
@export var enemy_touch_execute_enabled: bool = false
@export var trapped_timeout_sec: int = 8
@export var respawn_delay_sec: int = 0
@export var respawn_invincible_sec: int = 0
@export var death_display_sec: int = 2
@export var score_per_enemy_finish: int = 1
@export var score_tiebreak_policy: String = "draw"
@export var respawn_spawn_policy: String = "original_spawn"
