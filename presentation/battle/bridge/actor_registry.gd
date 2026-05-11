class_name BattleActorRegistry
extends RefCounted

const PlayerActorViewScript = preload("res://presentation/battle/actors/player_actor_view.gd")
const BubbleActorViewScript = preload("res://presentation/battle/actors/bubble_actor_view.gd")
const ItemActorViewScript = preload("res://presentation/battle/actors/item_actor_view.gd")

var player_scene: PackedScene = null
var bubble_scene: PackedScene = null
var item_scene: PackedScene = null

var _player_views: Dictionary = {}
var _bubble_views: Dictionary = {}
var _item_views: Dictionary = {}
var _player_visual_profiles: Dictionary = {}
var _channel_pass_mask_by_cell: Dictionary = {}
var _surface_virtual_z_by_cell: Dictionary = {}
var _surface_row_max_z: Dictionary = {}
var _surface_render_z_by_cell: Dictionary = {}
var _player_row_cells: Dictionary = {}


func configure(
	p_player_scene: PackedScene = null,
	p_bubble_scene: PackedScene = null,
	p_item_scene: PackedScene = null
) -> void:
	player_scene = p_player_scene
	bubble_scene = p_bubble_scene
	item_scene = p_item_scene


func configure_player_visual_profiles(player_visual_profiles: Dictionary) -> void:
	_player_visual_profiles = player_visual_profiles.duplicate()


func configure_channel_pass_mask_by_cell(channel_pass_mask_by_cell: Dictionary) -> void:
	_channel_pass_mask_by_cell = channel_pass_mask_by_cell.duplicate()


func configure_surface_virtual_z_by_cell(surface_virtual_z_by_cell: Dictionary) -> void:
	_surface_virtual_z_by_cell = surface_virtual_z_by_cell.duplicate()


func configure_surface_row_max_z(surface_row_max_z: Dictionary) -> void:
	_surface_row_max_z = surface_row_max_z.duplicate()


func configure_surface_render_z_by_cell(surface_render_z_by_cell: Dictionary) -> void:
	_surface_render_z_by_cell = surface_render_z_by_cell.duplicate()


func sync_players(parent: Node, players: Array[Dictionary]) -> void:
	_sync_group(parent, players, _player_views, player_scene, PlayerActorViewScript)


func sync_bubbles(parent: Node, bubbles: Array[Dictionary]) -> void:
	_sync_group(parent, bubbles, _bubble_views, bubble_scene, BubbleActorViewScript)


func sync_items(parent: Node, items: Array[Dictionary]) -> void:
	_sync_group(parent, items, _item_views, item_scene, ItemActorViewScript)




func clear_all() -> void:
	_prune_missing(_player_views, {})
	_prune_missing(_bubble_views, {})
	_prune_missing(_item_views, {})


func dispose() -> void:
	clear_all()
	player_scene = null
	bubble_scene = null
	item_scene = null
	_player_visual_profiles.clear()
	_player_views.clear()
	_bubble_views.clear()
	_item_views.clear()


func get_actor_view(entity_id: int) -> Node:
	if _player_views.has(entity_id):
		return _player_views.get(entity_id)
	if _bubble_views.has(entity_id):
		return _bubble_views.get(entity_id)
	if _item_views.has(entity_id):
		return _item_views.get(entity_id)
	return null


func debug_dump_actor_summary() -> Dictionary:
	return {
		"players": _player_views.size(),
		"bubbles": _bubble_views.size(),
		"items": _item_views.size(),
	}


func _sync_group(
	parent: Node,
	states: Array[Dictionary],
	views: Dictionary,
	scene: PackedScene,
	fallback_script: Script
) -> void:
	if parent == null:
		return

	var active_ids: Dictionary = {}
	for view_state in states:
		var entity_id := int(view_state.get("entity_id", -1))
		if entity_id < 0:
			continue

		active_ids[entity_id] = true
		var view: Node = views.get(entity_id, null)
		if view == null:
			view = _instantiate_view(scene, fallback_script)
			if view == null:
				continue
			parent.add_child(view)
			views[entity_id] = view

		if fallback_script == PlayerActorViewScript and view.has_method("configure_visual_profile"):
			var player_slot := int(view_state.get("player_slot", -1))
			view.configure_visual_profile(_player_visual_profiles.get(player_slot, null))
		if fallback_script == PlayerActorViewScript and view.has_method("configure_channel_occlusion"):
			view.configure_channel_occlusion(_channel_pass_mask_by_cell)
		if fallback_script == PlayerActorViewScript and view.has_method("configure_surface_priority_map"):
			view.configure_surface_priority_map(_surface_virtual_z_by_cell)
		if fallback_script == PlayerActorViewScript and view.has_method("configure_surface_row_priority_map"):
			view.configure_surface_row_priority_map(_surface_row_max_z)
		if fallback_script == PlayerActorViewScript and view.has_method("configure_surface_render_z_by_cell"):
			view.configure_surface_render_z_by_cell(_surface_render_z_by_cell)
		if fallback_script == BubbleActorViewScript and view.has_method("configure_channel_occlusion"):
			view.configure_channel_occlusion(_channel_pass_mask_by_cell)

		if view.has_method("apply_view_state"):
			view.apply_view_state(view_state)
		if fallback_script == PlayerActorViewScript:
			_player_row_cells[entity_id] = view_state.get("cell", Vector2i.ZERO) as Vector2i

	if fallback_script == PlayerActorViewScript:
		_enforce_player_z_row_order(views)

	_prune_missing(views, active_ids)



func _enforce_player_z_row_order(views: Dictionary) -> void:
	var row_players: Array[Dictionary] = []
	for entity_id in views:
		var view = views[entity_id]
		if view == null or not is_instance_valid(view):
			continue
		var cell: Vector2i = _player_row_cells.get(entity_id, Vector2i.ZERO)
		row_players.append({"view": view, "cell": cell, "z": view.z_index})
	if row_players.size() < 2:
		return
	row_players.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.cell.y < b.cell.y)
	var prev_z: int = int(row_players[0].z)
	for i in range(1, row_players.size()):
		var entry: Dictionary = row_players[i]
		if entry.cell.y > row_players[i - 1].cell.y:
			var min_z: int = prev_z + 1
			if int(entry.z) < min_z:
				entry.view.z_index = min_z
				entry.z = min_z
		prev_z = int(entry.z)


func _instantiate_view(scene: PackedScene, fallback_script: Script) -> Node:
	if scene != null:
		return scene.instantiate()
	if fallback_script == null:
		return null
	return fallback_script.new()


func _prune_missing(views: Dictionary, active_ids: Dictionary) -> void:
	var stale_ids: Array[int] = []
	for entity_id in views.keys():
		if not active_ids.has(entity_id):
			stale_ids.append(entity_id)

	for entity_id in stale_ids:
		var node: Node = views.get(entity_id)
		if node != null:
			node.free()
		views.erase(entity_id)
