class_name VisualSyncController
extends Node

var actor_views: Dictionary = {}
var actor_meta: Dictionary = {}
var correction_queue: Array[Dictionary] = []
var tile_size: float = 32.0
var hard_snap_tiles: float = 1.25
var local_light_speed: float = 14.0
var local_medium_speed: float = 24.0
var remote_light_speed: float = 18.0
var remote_medium_speed: float = 28.0


func bind_actor(entity_id: int, actor_view: Node, is_local: bool = false) -> void:
	actor_views[entity_id] = actor_view
	actor_meta[entity_id] = {
		"is_local": is_local,
		"target_visual_pos": _read_actor_pos(actor_view),
		"correction_speed": _default_speed(is_local),
		"correction_level": 0,
		"last_rollback_tick": -1
	}


func unbind_actor(entity_id: int) -> void:
	actor_views.erase(entity_id)
	actor_meta.erase(entity_id)


func push_correction(correction: Dictionary) -> void:
	correction_queue.append(correction.duplicate(true))


func on_rollback_corrected(corrected_entities: Array) -> void:
	for corrected in corrected_entities:
		push_correction(corrected)


func _process(delta: float) -> void:
	_flush_corrections()
	_update_actor_visuals(delta)


func _flush_corrections() -> void:
	while not correction_queue.is_empty():
		var correction: Dictionary = correction_queue.pop_front()
		var entity_id := int(correction.get("entity_id", -1))
		var actor: Node = actor_views.get(entity_id, null)
		if actor == null:
			continue

		var meta: Dictionary = actor_meta.get(entity_id, {})
		if meta.is_empty():
			continue

		if actor.has_method("apply_logic_state"):
			actor.apply_logic_state(correction)

		var target_pos := _extract_target_pos(actor, correction)
		var current_pos := _read_actor_pos(actor)
		_apply_correction(entity_id, actor, current_pos, target_pos, correction)

		if correction.has("facing") and actor.has_method("set_facing"):
			actor.set_facing(correction["facing"])

		if correction.has("anim_state") and actor.has_method("set_anim_state"):
			actor.set_anim_state(correction["anim_state"])


func _update_actor_visuals(delta: float) -> void:
	for entity_id in actor_views.keys():
		var actor: Node = actor_views.get(entity_id, null)
		if actor == null:
			continue

		var meta: Dictionary = actor_meta.get(entity_id, {})
		if meta.is_empty():
			continue

		var target_pos: Vector2 = meta.get("target_visual_pos", _read_actor_pos(actor))
		var current_pos := _read_actor_pos(actor)
		var correction_speed := float(meta.get("correction_speed", _default_speed(bool(meta.get("is_local", false)))))
		var lerp_weight : float = clamp(correction_speed * delta, 0.0, 1.0)
		var next_pos := current_pos.lerp(target_pos, lerp_weight)
		_write_actor_pos(actor, next_pos)


func _apply_correction(entity_id: int, actor: Node, current_pos: Vector2, target_pos: Vector2, correction: Dictionary) -> void:
	var meta: Dictionary = actor_meta.get(entity_id, {})
	var is_local := bool(meta.get("is_local", false))
	var distance := current_pos.distance_to(target_pos)
	var hard_snap_distance := tile_size * hard_snap_tiles

	meta["target_visual_pos"] = target_pos
	meta["last_rollback_tick"] = int(correction.get("rollback_tick", meta.get("last_rollback_tick", -1)))

	if distance < 8.0:
		meta["correction_level"] = 1
		meta["correction_speed"] = local_light_speed if is_local else remote_light_speed
	elif distance < min(hard_snap_distance, 48.0):
		meta["correction_level"] = 2
		meta["correction_speed"] = local_medium_speed if is_local else remote_medium_speed
	else:
		meta["correction_level"] = 3
		meta["correction_speed"] = _default_speed(is_local)
		_write_actor_pos(actor, target_pos)

	actor_meta[entity_id] = meta


func _extract_target_pos(actor: Node, correction: Dictionary) -> Vector2:
	if correction.has("target_visual_pos"):
		return correction["target_visual_pos"]

	if correction.has("grid_coord"):
		var grid_coord: Vector2i = correction["grid_coord"]
		var move_progress = correction.get("move_progress", Vector2.ZERO)
		var progress_vec := Vector2.ZERO
		if move_progress is Vector2:
			progress_vec = move_progress
		elif move_progress is Vector2i:
			progress_vec = Vector2(move_progress.x, move_progress.y)
		return Vector2(grid_coord.x, grid_coord.y) * tile_size + progress_vec

	if correction.has("grid_pos"):
		var grid_pos = correction["grid_pos"]
		if grid_pos is Vector2i:
			return Vector2(grid_pos.x, grid_pos.y) * tile_size
		if grid_pos is Vector2:
			return grid_pos * tile_size

	if actor.has_method("get_target_visual_pos"):
		return actor.get_target_visual_pos()

	return _read_actor_pos(actor)


func _read_actor_pos(actor: Node) -> Vector2:
	if actor == null:
		return Vector2.ZERO
	if "visual_pos" in actor:
		return actor.visual_pos
	if "global_position" in actor:
		return actor.global_position
	return Vector2.ZERO


func _write_actor_pos(actor: Node, value: Vector2) -> void:
	if actor == null:
		return
	if "visual_pos" in actor:
		actor.visual_pos = value
	if "target_visual_pos" in actor and actor.target_visual_pos == Vector2.ZERO:
		actor.target_visual_pos = value
	if "global_position" in actor:
		actor.global_position = value


func _default_speed(is_local: bool) -> float:
	return local_light_speed if is_local else remote_light_speed
