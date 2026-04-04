class_name BattleStateToViewMapper
extends RefCounted

var cell_size: float = 48.0

var _player_palette := [
	Color(0.20, 0.70, 1.0, 1.0),
	Color(1.0, 0.45, 0.25, 1.0),
	Color(0.35, 0.90, 0.50, 1.0),
	Color(1.0, 0.85, 0.30, 1.0),
]

var _item_palette := {
	1: Color(1.0, 0.85, 0.22, 1.0),
	2: Color(0.50, 0.95, 1.0, 1.0),
	3: Color(0.70, 1.0, 0.45, 1.0),
}
var _player_style_by_slot: Dictionary = {}
var _bubble_style_by_slot: Dictionary = {}
var _bubble_color_by_slot: Dictionary = {}


func configure_content_styles(player_style_by_slot: Dictionary, bubble_style_by_slot: Dictionary, bubble_color_by_slot: Dictionary = {}) -> void:
	_player_style_by_slot = player_style_by_slot.duplicate(true)
	_bubble_style_by_slot = bubble_style_by_slot.duplicate(true)
	_bubble_color_by_slot = bubble_color_by_slot.duplicate(true)


func build_grid_cache(world: SimWorld) -> Dictionary:
	var cells: Array[Dictionary] = []
	if world == null or world.state == null or world.state.grid == null:
		return {"cells": cells}

	var grid := world.state.grid
	for y in range(grid.height):
		for x in range(grid.width):
			var cell := grid.get_static_cell(x, y)
			cells.append({
				"x": x,
				"y": y,
				"tile_type": cell.tile_type,
				"tile_flags": cell.tile_flags,
			})

	return {"cells": cells}


func build_player_views(world: SimWorld) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if world == null:
		return result

	var player_ids := world.state.players.active_ids.duplicate()
	player_ids.sort()

	for player_id in player_ids:
		var player := world.state.players.get_player(player_id)
		if player == null:
			continue

		result.append(map_player_state(player))

	return result


func build_bubble_views(world: SimWorld) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if world == null:
		return result

	var bubble_ids := world.state.bubbles.active_ids.duplicate()
	bubble_ids.sort()

	for bubble_id in bubble_ids:
		var bubble := world.state.bubbles.get_bubble(bubble_id)
		if bubble == null:
			continue

		result.append(map_bubble_state(world, bubble))

	return result


func build_item_views(world: SimWorld) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if world == null:
		return result

	var item_ids := world.state.items.active_ids.duplicate()
	item_ids.sort()

	for item_id in item_ids:
		var item := world.state.items.get_item(item_id)
		if item == null or not item.alive or not item.visible:
			continue

		result.append(map_item_state(item))

	return result


func map_player_state(player: PlayerState) -> Dictionary:
	var default_color: Color = _player_palette[player.player_slot % _player_palette.size()]
	var configured_color: Color = _player_style_by_slot.get(player.player_slot, default_color)
	var input_move_x := 0
	var input_move_y := 0
	if player.last_applied_command != null:
		input_move_x = int(player.last_applied_command.move_x)
		input_move_y = int(player.last_applied_command.move_y)
	return {
		"entity_id": player.entity_id,
		"player_slot": player.player_slot,
		"alive": player.alive,
		"life_state": player.life_state,
		"facing": player.facing,
		"move_state": player.move_state,
		"input_move_x": input_move_x,
		"input_move_y": input_move_y,
		"position": _to_world_position(player.cell_x, player.cell_y),
		"offset": Vector2(player.offset_x, player.offset_y),
		"color": configured_color,
	}


func map_bubble_state(world: SimWorld, bubble: BubbleState) -> Dictionary:
	var bubble_style_id := _bubble_style_for_owner(world, bubble.owner_player_id)
	return {
		"entity_id": bubble.entity_id,
		"owner_player_id": bubble.owner_player_id,
		"bubble_style_id": bubble_style_id,
		"position": _to_world_position(bubble.cell_x, bubble.cell_y),
		"color": _bubble_color_for_owner(world, bubble.owner_player_id),
	}


func map_item_state(item: ItemState) -> Dictionary:
	return {
		"entity_id": item.entity_id,
		"item_type": item.item_type,
		"position": _to_world_position(item.cell_x, item.cell_y),
		"color": _item_palette.get(item.item_type, Color(1.0, 1.0, 1.0, 1.0)),
	}


func _to_world_position(cell_x: int, cell_y: int) -> Vector2:
	return Vector2(
		(float(cell_x) + 0.5) * cell_size,
		(float(cell_y) + 0.5) * cell_size
	)


func _bubble_color_for_owner(world: SimWorld, owner_player_id: int) -> Color:
	var player := world.state.players.get_player(owner_player_id)
	if player == null:
		return Color(0.30, 0.50, 1.0, 1.0)
	var default_color: Color = _player_palette[player.player_slot % _player_palette.size()].lightened(0.1)
	return _bubble_color_by_slot.get(player.player_slot, default_color)


func _bubble_style_for_owner(world: SimWorld, owner_player_id: int) -> String:
	var player := world.state.players.get_player(owner_player_id)
	if player == null:
		return ""
	return String(_bubble_style_by_slot.get(player.player_slot, ""))
