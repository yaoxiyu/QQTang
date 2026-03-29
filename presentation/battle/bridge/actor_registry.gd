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


func configure(
	p_player_scene: PackedScene = null,
	p_bubble_scene: PackedScene = null,
	p_item_scene: PackedScene = null
) -> void:
	player_scene = p_player_scene
	bubble_scene = p_bubble_scene
	item_scene = p_item_scene


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

		if view.has_method("apply_view_state"):
			view.apply_view_state(view_state)

	_prune_missing(views, active_ids)


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
