class_name ExplosionHitEntry
extends RefCounted

const ExplosionHitTypes = preload("res://gameplay/simulation/explosion/explosion_hit_types.gd")


var tick: int = 0
var source_bubble_id: int = -1
var source_player_id: int = -1
var source_cell_x: int = 0
var source_cell_y: int = 0
var target_type: int = ExplosionHitTypes.TargetType.PLAYER
var target_entity_id: int = -1
var target_cell_x: int = 0
var target_cell_y: int = 0
var target_aux_data: Dictionary = {}


func build_dedupe_key() -> String:
	match target_type:
		ExplosionHitTypes.TargetType.PLAYER:
			return "player:%d:%d:%d" % [target_entity_id, target_cell_x, target_cell_y]
		ExplosionHitTypes.TargetType.BUBBLE:
			return "bubble:%d:%d:%d" % [target_entity_id, target_cell_x, target_cell_y]
		ExplosionHitTypes.TargetType.ITEM:
			return "item:%d:%d:%d" % [target_entity_id, target_cell_x, target_cell_y]
		ExplosionHitTypes.TargetType.BREAKABLE_BLOCK:
			return "block:%d:%d" % [target_cell_x, target_cell_y]
		_:
			return "unknown:%d:%d:%d:%d" % [
				target_type,
				target_entity_id,
				target_cell_x,
				target_cell_y
			]


func duplicate_deep() -> ExplosionHitEntry:
	var copied := ExplosionHitEntry.new()
	copied.tick = tick
	copied.source_bubble_id = source_bubble_id
	copied.source_player_id = source_player_id
	copied.source_cell_x = source_cell_x
	copied.source_cell_y = source_cell_y
	copied.target_type = target_type
	copied.target_entity_id = target_entity_id
	copied.target_cell_x = target_cell_x
	copied.target_cell_y = target_cell_y
	copied.target_aux_data = target_aux_data.duplicate(true)
	return copied
