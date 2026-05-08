class_name BattleDepth
extends RefCounted

const ROW_STEP := 100
const WITHIN_ROW_STEP := 10

const LAYER_PRIORITY_FX := 1
const LAYER_PRIORITY_ACTOR := 2
const LAYER_PRIORITY_SURFACE := 3

const GROUND_Z_BIAS := 0
const SPAWN_MARKER_Z_BIAS := 1
const OCCLUDER_Z_BIAS := 0
const BUBBLE_Z_BIAS := 0
const EXPLOSION_Z_BIAS := 1
const ITEM_Z_BIAS := 2
const PLAYER_Z_BIAS := 0
const SURFACE_Z_BIAS := 5


static func ground_z(cell: Vector2i) -> int:
	return _floor_z(cell, GROUND_Z_BIAS)


static func spawn_marker_z(cell: Vector2i) -> int:
	return _floor_z(cell, SPAWN_MARKER_Z_BIAS)


static func occluder_z(cell: Vector2i) -> int:
	return _row_z(LAYER_PRIORITY_SURFACE, cell, OCCLUDER_Z_BIAS)


static func bubble_z(cell: Vector2i, z_bias: int = 0) -> int:
	return _row_z(LAYER_PRIORITY_FX, cell, BUBBLE_Z_BIAS + z_bias)


static func explosion_z(cell: Vector2i, z_bias: int = 0) -> int:
	return _row_z(LAYER_PRIORITY_FX, cell, EXPLOSION_Z_BIAS + z_bias)


static func item_z(cell: Vector2i, z_bias: int = 0) -> int:
	return _row_z(LAYER_PRIORITY_FX, cell, ITEM_Z_BIAS + z_bias)


static func player_z(cell: Vector2i, z_bias: int = 0) -> int:
	return _row_z(LAYER_PRIORITY_ACTOR, cell, PLAYER_Z_BIAS + z_bias)


static func surface_z(cell: Vector2i, z_bias: int = 0) -> int:
	return _row_z(LAYER_PRIORITY_SURFACE, cell, SURFACE_Z_BIAS + z_bias)


static func _floor_z(cell: Vector2i, z_bias: int) -> int:
	return -cell.x + z_bias


static func _row_z(layer_priority: int, cell: Vector2i, z_bias: int) -> int:
	return cell.y * ROW_STEP + layer_priority * WITHIN_ROW_STEP - cell.x + z_bias
