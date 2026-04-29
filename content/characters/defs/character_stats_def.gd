class_name CharacterStatsDef
extends Resource

@export var stats_id: String = ""
@export var initial_bubble_count: int = 1
@export var max_bubble_count: int = 5
@export var initial_bubble_power: int = 1
@export var max_bubble_power: int = 5
@export var initial_move_speed: int = 1
@export var max_move_speed: int = 9
@export var content_hash: String = ""

var base_bomb_count: int:
	get:
		return initial_bubble_count
	set(value):
		initial_bubble_count = value

var base_firepower: int:
	get:
		return initial_bubble_power
	set(value):
		initial_bubble_power = value

var base_move_speed: int:
	get:
		return initial_move_speed
	set(value):
		initial_move_speed = value
