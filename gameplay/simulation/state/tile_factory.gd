# 角色：
# 格子构造工厂，统一构造默认格子
#
# 读写边界：
# - 只在初始化时调用
#
# 禁止事项：
# - 不得在此写规则逻辑

class_name TileFactory
extends RefCounted

# ====================
# 格子构造方法
# ====================

static func make_empty() -> CellStatic:
	var cell := CellStatic.new()
	cell.tile_type = TileConstants.TileType.EMPTY
	cell.tile_flags = 0
	return cell

static func make_solid_wall() -> CellStatic:
	var cell := CellStatic.new()
	cell.tile_type = TileConstants.TileType.SOLID_WALL
	cell.tile_flags = TileConstants.TILE_BLOCK_MOVE | TileConstants.TILE_BLOCK_EXPLOSION
	return cell

static func make_breakable_block() -> CellStatic:
	var cell := CellStatic.new()
	cell.tile_type = TileConstants.TileType.BREAKABLE_BLOCK
	cell.tile_flags = TileConstants.TILE_BLOCK_MOVE | TileConstants.TILE_BLOCK_EXPLOSION | TileConstants.TILE_BREAKABLE | TileConstants.TILE_CAN_SPAWN_ITEM
	return cell

static func make_spawn(spawn_group_id: int = 0) -> CellStatic:
	var cell := CellStatic.new()
	cell.tile_type = TileConstants.TileType.SPAWN
	cell.tile_flags = TileConstants.TILE_IS_SPAWN
	cell.spawn_group_id = spawn_group_id
	return cell

static func make_mechanism(mechanism_id: int = 0, extra_flags: int = TileConstants.TILE_IS_MECHANISM) -> CellStatic:
	var cell := CellStatic.new()
	cell.tile_type = TileConstants.TileType.MECHANISM
	cell.tile_flags = extra_flags
	cell.mechanism_id = mechanism_id
	return cell
