class_name BattleActorRegistry
extends RefCounted

const PlayerActorViewScript = preload("res://presentation/battle/actors/player_actor_view.gd")
const BubbleActorViewScript = preload("res://presentation/battle/actors/bubble_actor_view.gd")
const ItemActorViewScript = preload("res://presentation/battle/actors/item_actor_view.gd")
const LogPresentationScript = preload("res://app/logging/log_presentation.gd")

const BUBBLE_PRUNE_GRACE_TICKS := 10

var player_scene: PackedScene = null
var bubble_scene: PackedScene = null
var item_scene: PackedScene = null

var _player_views: Dictionary = {}
var _bubble_views: Dictionary = {}
var _item_views: Dictionary = {}
var _bubble_identity_by_id: Dictionary = {}
var _bubble_pending_prune: Dictionary = {}
var _player_visual_profiles: Dictionary = {}
var _channel_pass_mask_by_cell: Dictionary = {}
var _channel_visual_policy_by_cell: Dictionary = {}
var _surface_virtual_z_by_cell: Dictionary = {}
var _surface_row_max_z: Dictionary = {}
var _surface_render_z_by_cell: Dictionary = {}
var _surface_occlusion_by_cell: Dictionary = {}
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


func configure_channel_visual_policy_by_cell(channel_visual_policy_by_cell: Dictionary) -> void:
	_channel_visual_policy_by_cell = channel_visual_policy_by_cell.duplicate(true)


func configure_surface_virtual_z_by_cell(surface_virtual_z_by_cell: Dictionary) -> void:
	_surface_virtual_z_by_cell = surface_virtual_z_by_cell.duplicate()


func configure_surface_row_max_z(surface_row_max_z: Dictionary) -> void:
	_surface_row_max_z = surface_row_max_z.duplicate()


func configure_surface_render_z_by_cell(surface_render_z_by_cell: Dictionary) -> void:
	_surface_render_z_by_cell = surface_render_z_by_cell.duplicate()


func configure_surface_occlusion_by_cell(surface_occlusion_by_cell: Dictionary) -> void:
	_surface_occlusion_by_cell = surface_occlusion_by_cell.duplicate(true)


func sync_players(parent: Node, players: Array[Dictionary]) -> void:
	_sync_group(parent, players, _player_views, player_scene, PlayerActorViewScript)


func sync_bubbles(parent: Node, bubbles: Array[Dictionary]) -> void:
	_remap_bubble_views_by_owner_cell(bubbles)
	_sync_bubble_group(parent, bubbles)
	_refresh_bubble_identity_index(bubbles)


func _remap_bubble_views_by_owner_cell(bubbles: Array[Dictionary]) -> void:
	if _bubble_views.is_empty():
		return
	var incoming_ids: Dictionary = {}
	var unmatched_incoming: Array[Dictionary] = []
	for view_state in bubbles:
		var entity_id := int(view_state.get("entity_id", -1))
		if entity_id < 0:
			continue
		incoming_ids[entity_id] = true
		if _bubble_views.has(entity_id):
			continue
		unmatched_incoming.append(view_state)
	if unmatched_incoming.is_empty():
		return
	var orphan_old_ids: Array[int] = []
	for old_id in _bubble_views.keys():
		if not incoming_ids.has(old_id):
			orphan_old_ids.append(old_id)
	if orphan_old_ids.is_empty():
		return
	var orphan_by_identity: Dictionary = {}
	for old_id in orphan_old_ids:
		var identity: String = _bubble_identity_by_id.get(old_id, "")
		if identity.is_empty():
			continue
		orphan_by_identity[identity] = old_id
	if orphan_by_identity.is_empty():
		return
	for view_state in unmatched_incoming:
		var owner_player_id := int(view_state.get("owner_player_id", -1))
		var cell := view_state.get("cell", Vector2i.ZERO) as Vector2i
		var identity := _bubble_identity_key(owner_player_id, cell)
		if not orphan_by_identity.has(identity):
			continue
		var old_id: int = orphan_by_identity[identity]
		orphan_by_identity.erase(identity)
		var new_id := int(view_state.get("entity_id", -1))
		if new_id < 0 or new_id == old_id:
			continue
		var view: Node = _bubble_views.get(old_id, null)
		if view == null:
			_bubble_views.erase(old_id)
			_bubble_identity_by_id.erase(old_id)
			_bubble_pending_prune.erase(old_id)
			continue
		_bubble_views.erase(old_id)
		_bubble_identity_by_id.erase(old_id)
		_bubble_pending_prune.erase(old_id)
		_bubble_views[new_id] = view
		_bubble_identity_by_id[new_id] = identity
		_bubble_pending_prune.erase(new_id)
		if view.has_method("set"):
			view.set("bubble_id", new_id)
		LogPresentationScript.info(
			"bubble_view_remap old_id=%d new_id=%d identity=%s" % [old_id, new_id, identity],
			"", 0, "presentation.bubble.remap"
		)
	for orphan_identity in orphan_by_identity.keys():
		LogPresentationScript.info(
			"bubble_view_remap_miss orphan_id=%d identity=%s reason=no_incoming_match" % [
				int(orphan_by_identity[orphan_identity]),
				String(orphan_identity),
			],
			"", 0, "presentation.bubble.remap"
		)
	for view_state in unmatched_incoming:
		var entity_id := int(view_state.get("entity_id", -1))
		if entity_id < 0 or _bubble_views.has(entity_id):
			continue
		var owner_player_id := int(view_state.get("owner_player_id", -1))
		var cell := view_state.get("cell", Vector2i.ZERO) as Vector2i
		LogPresentationScript.info(
			"bubble_view_remap_skip new_id=%d identity=%s reason=no_orphan_match" % [
				entity_id, _bubble_identity_key(owner_player_id, cell),
			],
			"", 0, "presentation.bubble.remap"
		)


func _refresh_bubble_identity_index(bubbles: Array[Dictionary]) -> void:
	var fresh_index: Dictionary = {}
	for view_state in bubbles:
		var entity_id := int(view_state.get("entity_id", -1))
		if entity_id < 0 or not _bubble_views.has(entity_id):
			continue
		var owner_player_id := int(view_state.get("owner_player_id", -1))
		var cell := view_state.get("cell", Vector2i.ZERO) as Vector2i
		fresh_index[entity_id] = _bubble_identity_key(owner_player_id, cell)
	_bubble_identity_by_id = fresh_index


func _bubble_identity_key(owner_player_id: int, cell: Vector2i) -> String:
	return "%d|%d|%d" % [owner_player_id, cell.x, cell.y]


func sync_items(parent: Node, items: Array[Dictionary]) -> void:
	_sync_group(parent, items, _item_views, item_scene, ItemActorViewScript)


func _sync_bubble_group(parent: Node, states: Array[Dictionary]) -> void:
	if parent == null:
		return

	var active_ids: Dictionary = {}
	for view_state in states:
		var entity_id := int(view_state.get("entity_id", -1))
		if entity_id < 0:
			continue
		active_ids[entity_id] = true
		var view: Node = _bubble_views.get(entity_id, null)
		if view == null:
			view = _instantiate_view(bubble_scene, BubbleActorViewScript)
			if view == null:
				continue
			parent.add_child(view)
			_bubble_views[entity_id] = view
		_bubble_pending_prune.erase(entity_id)
		if view.has_method("configure_channel_occlusion"):
			view.configure_channel_occlusion(_channel_pass_mask_by_cell)
		if view.has_method("configure_channel_visual_policy"):
			view.configure_channel_visual_policy(_channel_visual_policy_by_cell)
		if view.has_method("apply_view_state"):
			view.apply_view_state(view_state)

	_grace_prune_bubbles(active_ids)


func _grace_prune_bubbles(active_ids: Dictionary) -> void:
	var to_free: Array[int] = []
	for entity_id in _bubble_views.keys():
		if active_ids.has(entity_id):
			continue
		var elapsed: int = int(_bubble_pending_prune.get(entity_id, 0)) + 1
		if elapsed >= BUBBLE_PRUNE_GRACE_TICKS:
			to_free.append(entity_id)
		else:
			_bubble_pending_prune[entity_id] = elapsed

	for entity_id in to_free:
		var node: Node = _bubble_views.get(entity_id)
		if node != null:
			node.free()
		_bubble_views.erase(entity_id)
		_bubble_identity_by_id.erase(entity_id)
		_bubble_pending_prune.erase(entity_id)
		LogPresentationScript.info(
			"bubble_view_grace_freed entity_id=%d grace_ticks=%d" % [entity_id, BUBBLE_PRUNE_GRACE_TICKS],
			"", 0, "presentation.bubble.remap"
		)




func clear_all() -> void:
	_prune_missing(_player_views, {})
	_prune_missing(_bubble_views, {})
	_prune_missing(_item_views, {})
	_bubble_identity_by_id.clear()
	_bubble_pending_prune.clear()


func dispose() -> void:
	clear_all()
	player_scene = null
	bubble_scene = null
	item_scene = null
	_player_visual_profiles.clear()
	_player_views.clear()
	_bubble_views.clear()
	_item_views.clear()
	_bubble_identity_by_id.clear()
	_bubble_pending_prune.clear()


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
		if fallback_script == PlayerActorViewScript and view.has_method("configure_surface_occlusion_by_cell"):
			view.configure_surface_occlusion_by_cell(_surface_occlusion_by_cell)
		if fallback_script == BubbleActorViewScript and view.has_method("configure_channel_occlusion"):
			view.configure_channel_occlusion(_channel_pass_mask_by_cell)
		if fallback_script == BubbleActorViewScript and view.has_method("configure_channel_visual_policy"):
			view.configure_channel_visual_policy(_channel_visual_policy_by_cell)

		if view.has_method("apply_view_state"):
			view.apply_view_state(view_state)
		if fallback_script == PlayerActorViewScript:
			var _cell := view_state.get("cell", Vector2i.ZERO) as Vector2i
			var _offset_y := int((view_state.get("offset", Vector2.ZERO) as Vector2).y)
			_player_row_cells[entity_id] = {"cell": _cell, "offset_y": _offset_y}

	if fallback_script == PlayerActorViewScript:
		_enforce_player_z_row_order(views)

	_prune_missing(views, active_ids)



func _enforce_player_z_row_order(views: Dictionary) -> void:
	var row_players: Array[Dictionary] = []
	for entity_id in views:
		var view = views[entity_id]
		if view == null or not is_instance_valid(view):
			continue
		var row_info: Dictionary = _player_row_cells.get(entity_id, {"cell": Vector2i.ZERO, "offset_y": 0})
		var cell: Vector2i = row_info.get("cell", Vector2i.ZERO) as Vector2i
		var offset_y: int = int(row_info.get("offset_y", 0))
		row_players.append({"view": view, "cell": cell, "offset_y": offset_y, "z": view.z_index})
	if row_players.size() < 2:
		return
	row_players.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.cell.y != b.cell.y:
			return a.cell.y < b.cell.y
		if a.cell.x != b.cell.x:
			return a.cell.x > b.cell.x
		return a.offset_y < b.offset_y
	)
	var prev_z: int = int(row_players[0].z)
	for i in range(1, row_players.size()):
		var entry: Dictionary = row_players[i]
		if entry.cell.y > row_players[i - 1].cell.y:
			var min_z: int = prev_z + 1
			if int(entry.z) < min_z:
				entry.view.z_index = min_z
				entry.z = min_z
		elif int(entry.z) <= prev_z:
			var need_bump: bool = false
			if entry.cell.x < row_players[i - 1].cell.x:
				need_bump = true
			elif entry.cell.x == row_players[i - 1].cell.x and entry.offset_y > row_players[i - 1].offset_y:
				need_bump = true
			if need_bump:
				entry.view.z_index = prev_z + 1
				entry.z = prev_z + 1
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
