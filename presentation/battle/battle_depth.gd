class_name BattleDepth
extends RefCounted

const ROW_Z_STEP := 20
const GROUND_Z := 0
const FX_LAYER_BASE := 500
const ACTOR_LAYER_BASE := 1000
const SURFACE_LAYER_BASE := 2000

const BUBBLE_Z_BIAS := 4
const EXPLOSION_Z_BIAS := 5
const ITEM_Z_BIAS := 6
const PLAYER_Z_BIAS := 8
const SURFACE_Z_BIAS := 10


static func bubble_z(cell: Vector2i, z_bias: int = 0) -> int:
	return _dynamic_z(FX_LAYER_BASE, cell, BUBBLE_Z_BIAS + z_bias)


static func explosion_z(cell: Vector2i, z_bias: int = 0) -> int:
	return _dynamic_z(FX_LAYER_BASE, cell, EXPLOSION_Z_BIAS + z_bias)


static func item_z(cell: Vector2i, z_bias: int = 0) -> int:
	return _dynamic_z(FX_LAYER_BASE, cell, ITEM_Z_BIAS + z_bias)


static func player_z(cell: Vector2i, z_bias: int = 0) -> int:
	return _dynamic_z(ACTOR_LAYER_BASE, cell, PLAYER_Z_BIAS + z_bias)


static func surface_z(cell: Vector2i, z_bias: int = 0) -> int:
	return _dynamic_z(SURFACE_LAYER_BASE, cell, SURFACE_Z_BIAS + z_bias)


static func _dynamic_z(layer_base: int, cell: Vector2i, z_bias: int) -> int:
	return layer_base + cell.y * ROW_Z_STEP - cell.x + z_bias
