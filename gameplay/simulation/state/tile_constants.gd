# 角色：
# Tile 类型和 Flags 常量定义
#
# 读写边界：
# - 只读常量
#
# 禁止事项：
# - 不得在此写逻辑

class_name TileConstants
extends RefCounted

# ====================
# TileType 枚举
# ====================

enum TileType {
	EMPTY = 0,
	SOLID_WALL = 1,
	BREAKABLE_BLOCK = 2,
	SPAWN = 3,
	MECHANISM = 4
}

# ====================
# TileFlags 位标志
# ====================

# 阻挡移动
const TILE_BLOCK_MOVE := 1 << 0

# 阻挡爆炸
const TILE_BLOCK_EXPLOSION := 1 << 1

# 可破坏
const TILE_BREAKABLE := 1 << 2

# 可掉落道具
const TILE_CAN_SPAWN_ITEM := 1 << 3

# 出生点
const TILE_IS_SPAWN := 1 << 4

# 机关格
const TILE_IS_MECHANISM := 1 << 5

# ====================
# Direction pass mask
# ====================

const PASS_N := 1
const PASS_E := 2
const PASS_S := 4
const PASS_W := 8
const PASS_ALL := PASS_N | PASS_E | PASS_S | PASS_W
const PASS_HORIZONTAL := PASS_E | PASS_W
const PASS_VERTICAL := PASS_N | PASS_S
const PASS_NONE := 0
