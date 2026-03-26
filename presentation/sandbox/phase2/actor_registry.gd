class_name Phase2ActorRegistry
extends RefCounted

const PlayerActorViewScript = preload("res://presentation/sandbox/phase2/player_actor_view.gd")
const BubbleActorViewScript = preload("res://presentation/sandbox/phase2/bubble_actor_view.gd")
const ItemActorViewScript = preload("res://presentation/sandbox/phase2/item_actor_view.gd")

var _player_views: Dictionary = {}
var _bubble_views: Dictionary = {}
var _item_views: Dictionary = {}


func sync_players(parent: Node, players: Array[Dictionary]) -> void:
	if parent == null:
		return

	var active_ids: Dictionary = {}
	for player_state in players:
		var entity_id := int(player_state.get("entity_id", -1))
		if entity_id < 0:
			continue
		active_ids[entity_id] = true
		var view: Phase2PlayerActorView = _player_views.get(entity_id, null)
		if view == null:
			view = PlayerActorViewScript.new()
			parent.add_child(view)
			_player_views[entity_id] = view
		view.apply_state(player_state)

	_prune_missing(_player_views, active_ids)


func sync_bubbles(parent: Node, bubbles: Array[Dictionary]) -> void:
	if parent == null:
		return

	var active_ids: Dictionary = {}
	for bubble_state in bubbles:
		var entity_id := int(bubble_state.get("entity_id", -1))
		if entity_id < 0:
			continue
		active_ids[entity_id] = true
		var view: Phase2BubbleActorView = _bubble_views.get(entity_id, null)
		if view == null:
			view = BubbleActorViewScript.new()
			parent.add_child(view)
			_bubble_views[entity_id] = view
		view.apply_state(bubble_state)

	_prune_missing(_bubble_views, active_ids)


func sync_items(parent: Node, items: Array[Dictionary]) -> void:
	if parent == null:
		return

	var active_ids: Dictionary = {}
	for item_state in items:
		var entity_id := int(item_state.get("entity_id", -1))
		if entity_id < 0:
			continue
		active_ids[entity_id] = true
		var view: Phase2ItemActorView = _item_views.get(entity_id, null)
		if view == null:
			view = ItemActorViewScript.new()
			parent.add_child(view)
			_item_views[entity_id] = view
		view.apply_state(item_state)

	_prune_missing(_item_views, active_ids)


func clear_all() -> void:
	_prune_missing(_player_views, {})
	_prune_missing(_bubble_views, {})
	_prune_missing(_item_views, {})


func _prune_missing(views: Dictionary, active_ids: Dictionary) -> void:
	var stale_ids: Array[int] = []
	for entity_id in views.keys():
		if not active_ids.has(entity_id):
			stale_ids.append(entity_id)

	for entity_id in stale_ids:
		var node: Node = views.get(entity_id)
		if node != null:
			node.queue_free()
		views.erase(entity_id)
