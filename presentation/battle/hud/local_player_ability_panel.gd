class_name LocalPlayerAbilityPanel
extends PanelContainer

@export var bomb_count_label_path: NodePath = ^"HBoxContainer/BombCountLabel"
@export var power_label_path: NodePath = ^"HBoxContainer/PowerLabel"
@export var speed_label_path: NodePath = ^"HBoxContainer/SpeedLabel"
@export var ability_label_path: NodePath = ^"HBoxContainer/AbilityLabel"

var bomb_count_label: Label = null
var power_label: Label = null
var speed_label: Label = null
var ability_label: Label = null


func _ready() -> void:
	if has_node(bomb_count_label_path):
		bomb_count_label = get_node(bomb_count_label_path)
	if has_node(power_label_path):
		power_label = get_node(power_label_path)
	if has_node(speed_label_path):
		speed_label = get_node(speed_label_path)
	if has_node(ability_label_path):
		ability_label = get_node(ability_label_path)
	apply_player_ability({})


func apply_player_ability(player_status: Dictionary) -> void:
	var bomb_available := int(player_status.get("bomb_available", 0))
	var bomb_capacity := int(player_status.get("bomb_capacity", 0))
	var bomb_range := int(player_status.get("bomb_range", 0))
	var speed_level := int(player_status.get("speed_level", 0))
	if bomb_count_label != null:
		bomb_count_label.text = "Bomb %d/%d" % [bomb_available, bomb_capacity]
	if power_label != null:
		power_label.text = "Power %d/%d" % [bomb_range, int(player_status.get("max_bomb_range", 0))]
	if speed_label != null:
		speed_label.text = "Speed %d/%d" % [speed_level, int(player_status.get("max_speed_level", 0))]
