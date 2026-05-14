class_name ChannelVisualPolicy
extends RefCounted

const PASS_UP := 1
const PASS_RIGHT := 2
const PASS_DOWN := 4
const PASS_LEFT := 8


static func resolve_bubble_hidden(
	cell: Vector2i,
	channel_pass_mask_by_cell: Dictionary,
	visual_policy_by_cell: Dictionary = {}
) -> bool:
	if visual_policy_by_cell.has(cell):
		var policy = visual_policy_by_cell[cell]
		if policy is Dictionary and (policy as Dictionary).has("hide_bubble"):
			return bool((policy as Dictionary).get("hide_bubble", false))
	return channel_pass_mask_by_cell.has(cell)


static func resolve_player_body_hidden(world_position: Vector2, cell_size: float, channel_pass_mask_by_cell: Dictionary) -> bool:
	if channel_pass_mask_by_cell.is_empty():
		return false
	var safe_cell_size := maxf(cell_size, 1.0)
	var hide_distance_sq := (safe_cell_size * 0.5) * (safe_cell_size * 0.5)
	var current_cell := Vector2i(
		int(floor(world_position.x / safe_cell_size)),
		int(floor(world_position.y / safe_cell_size))
	)
	for sample_cell in _candidate_cells(current_cell):
		if not channel_pass_mask_by_cell.has(sample_cell):
			continue
		var channel_center := Vector2((float(sample_cell.x) + 0.5) * safe_cell_size, (float(sample_cell.y) + 0.5) * safe_cell_size)
		if world_position.distance_squared_to(channel_center) <= hide_distance_sq:
			return true
	return _is_on_connected_channel_edge(world_position, current_cell, safe_cell_size, channel_pass_mask_by_cell)


static func resolve_player_z(
	base_z: int,
	player_cell: Vector2i,
	candidate_cells: Array[Vector2i],
	surface_occlusion_by_cell: Dictionary,
	surface_row_max_z: Dictionary
) -> Dictionary:
	var resolved := base_z
	var local_max := -2147483648
	for candidate in candidate_cells:
		if not surface_occlusion_by_cell.has(candidate):
			continue
		var occlusion = surface_occlusion_by_cell[candidate]
		if occlusion is Dictionary:
			var entry := occlusion as Dictionary
			var render_z := int(entry.get("render_z", entry.get("surface_z", -2147483648)))
			local_max = maxi(local_max, render_z)
		else:
			local_max = maxi(local_max, int(occlusion))
	if local_max >= resolved:
		return {"z": local_max + 1, "reason": "surface_local"}
	var row_fallback := int(surface_row_max_z.get(player_cell.y, -2147483648))
	if row_fallback >= resolved:
		return {"z": row_fallback + 1, "reason": "surface_row_fallback"}
	return {"z": resolved, "reason": "base"}


static func _candidate_cells(current_cell: Vector2i) -> Array[Vector2i]:
	return [
		current_cell,
		current_cell + Vector2i.LEFT,
		current_cell + Vector2i.RIGHT,
		current_cell + Vector2i.UP,
		current_cell + Vector2i.DOWN,
	]


static func _is_on_connected_channel_edge(
	world_position: Vector2,
	current_cell: Vector2i,
	cell_size: float,
	channel_pass_mask_by_cell: Dictionary
) -> bool:
	var epsilon := 0.001
	var x_edge: float = round(world_position.x / cell_size)
	if absf(world_position.x - x_edge * cell_size) <= epsilon:
		var left_cell := Vector2i(int(x_edge) - 1, current_cell.y)
		var right_cell := Vector2i(int(x_edge), current_cell.y)
		if _channels_connected(left_cell, right_cell, Vector2i.RIGHT, channel_pass_mask_by_cell):
			return true
	var y_edge: float = round(world_position.y / cell_size)
	if absf(world_position.y - y_edge * cell_size) <= epsilon:
		var up_cell := Vector2i(current_cell.x, int(y_edge) - 1)
		var down_cell := Vector2i(current_cell.x, int(y_edge))
		if _channels_connected(up_cell, down_cell, Vector2i.DOWN, channel_pass_mask_by_cell):
			return true
	return false


static func _channels_connected(
	a: Vector2i,
	b: Vector2i,
	dir_from_a_to_b: Vector2i,
	channel_pass_mask_by_cell: Dictionary
) -> bool:
	var a_mask := int(channel_pass_mask_by_cell.get(a, -1))
	var b_mask := int(channel_pass_mask_by_cell.get(b, -1))
	if a_mask < 0 or b_mask < 0:
		return false
	if dir_from_a_to_b == Vector2i.RIGHT:
		return (a_mask & PASS_RIGHT) != 0 and (b_mask & PASS_LEFT) != 0
	if dir_from_a_to_b == Vector2i.DOWN:
		return (a_mask & PASS_DOWN) != 0 and (b_mask & PASS_UP) != 0
	return false
