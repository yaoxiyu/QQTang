class_name NativeBattlePackedSchema
extends RefCounted

const SCHEMA_VERSION := 1

const HEADER_STRIDE := 8
const HEADER_SCHEMA_VERSION := 0
const HEADER_TICK_ID := 1
const HEADER_MAP_WIDTH := 2
const HEADER_MAP_HEIGHT := 3
const HEADER_PLAYER_COUNT := 4
const HEADER_BUBBLE_COUNT := 5
const HEADER_ITEM_COUNT := 6
const HEADER_GRID_CELL_COUNT := 7

const PLAYER_STRIDE := 16
const PLAYER_ID_HASH := 0
const PLAYER_TEAM_ID_HASH := 1
const PLAYER_X_SUBCELL := 2
const PLAYER_Y_SUBCELL := 3
const PLAYER_DIR := 4
const PLAYER_STATE := 5
const PLAYER_ALIVE := 6
const PLAYER_TRAPPED := 7
const PLAYER_MOVE_SPEED_SUBCELL := 8
const PLAYER_BOMB_CAPACITY := 9
const PLAYER_FIRE_POWER := 10
const PLAYER_ACTIVE_BUBBLE_COUNT := 11
const PLAYER_INPUT_SEQ := 12
const PLAYER_CHECKSUM_SALT := 13
const PLAYER_RESERVED0 := 14
const PLAYER_RESERVED1 := 15

const BUBBLE_STRIDE := 12
const BUBBLE_ID_HASH := 0
const BUBBLE_OWNER_PLAYER_ID_HASH := 1
const BUBBLE_X_CELL := 2
const BUBBLE_Y_CELL := 3
const BUBBLE_FIRE_POWER := 4
const BUBBLE_STATE := 5
const BUBBLE_PLACED_TICK := 6
const BUBBLE_EXPLODE_TICK := 7
const BUBBLE_CHAIN_TRIGGERED := 8
const BUBBLE_STYLE_ID_HASH := 9
const BUBBLE_RESERVED0 := 10
const BUBBLE_RESERVED1 := 11

const ITEM_STRIDE := 8
const ITEM_ID_HASH := 0
const ITEM_TYPE_HASH := 1
const ITEM_X_CELL := 2
const ITEM_Y_CELL := 3
const ITEM_STATE := 4
const ITEM_SPAWN_TICK := 5
const ITEM_RESERVED0 := 6
const ITEM_RESERVED1 := 7

const GRID_STRIDE := 4
const GRID_CELL_TYPE := 0
const GRID_BLOCKER_FLAGS := 1
const GRID_OCCUPANT_FLAGS := 2
const GRID_RESERVED0 := 3


static func stable_hash(value: String) -> int:
	var text := String(value)
	var hash := 2166136261
	for i in text.length():
		hash = int((hash ^ text.unicode_at(i)) * 16777619) & 0x7fffffff
	return hash
