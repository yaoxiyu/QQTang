#pragma once

#include <cstdint>

namespace qqt::packed_schema {
constexpr int32_t SCHEMA_VERSION = 1;

constexpr int32_t HEADER_STRIDE = 8;
constexpr int32_t HEADER_SCHEMA_VERSION = 0;
constexpr int32_t HEADER_TICK_ID = 1;
constexpr int32_t HEADER_MAP_WIDTH = 2;
constexpr int32_t HEADER_MAP_HEIGHT = 3;
constexpr int32_t HEADER_PLAYER_COUNT = 4;
constexpr int32_t HEADER_BUBBLE_COUNT = 5;
constexpr int32_t HEADER_ITEM_COUNT = 6;
constexpr int32_t HEADER_GRID_CELL_COUNT = 7;

constexpr int32_t PLAYER_STRIDE = 16;
constexpr int32_t PLAYER_ID_HASH = 0;
constexpr int32_t PLAYER_TEAM_ID_HASH = 1;
constexpr int32_t PLAYER_X_SUBCELL = 2;
constexpr int32_t PLAYER_Y_SUBCELL = 3;
constexpr int32_t PLAYER_DIR = 4;
constexpr int32_t PLAYER_STATE = 5;
constexpr int32_t PLAYER_ALIVE = 6;
constexpr int32_t PLAYER_TRAPPED = 7;
constexpr int32_t PLAYER_MOVE_SPEED_SUBCELL = 8;
constexpr int32_t PLAYER_BOMB_CAPACITY = 9;
constexpr int32_t PLAYER_FIRE_POWER = 10;
constexpr int32_t PLAYER_ACTIVE_BUBBLE_COUNT = 11;
constexpr int32_t PLAYER_INPUT_SEQ = 12;
constexpr int32_t PLAYER_CHECKSUM_SALT = 13;
constexpr int32_t PLAYER_RESERVED0 = 14;
constexpr int32_t PLAYER_RESERVED1 = 15;

constexpr int32_t BUBBLE_STRIDE = 12;
constexpr int32_t BUBBLE_ID_HASH = 0;
constexpr int32_t BUBBLE_OWNER_PLAYER_ID_HASH = 1;
constexpr int32_t BUBBLE_X_CELL = 2;
constexpr int32_t BUBBLE_Y_CELL = 3;
constexpr int32_t BUBBLE_FIRE_POWER = 4;
constexpr int32_t BUBBLE_STATE = 5;
constexpr int32_t BUBBLE_PLACED_TICK = 6;
constexpr int32_t BUBBLE_EXPLODE_TICK = 7;
constexpr int32_t BUBBLE_CHAIN_TRIGGERED = 8;
constexpr int32_t BUBBLE_STYLE_ID_HASH = 9;
constexpr int32_t BUBBLE_TYPE = 10;
constexpr int32_t BUBBLE_FOOTPRINT_CELLS = 11;

constexpr int32_t ITEM_STRIDE = 8;
constexpr int32_t ITEM_ID_HASH = 0;
constexpr int32_t ITEM_TYPE_HASH = 1;
constexpr int32_t ITEM_X_CELL = 2;
constexpr int32_t ITEM_Y_CELL = 3;
constexpr int32_t ITEM_STATE = 4;
constexpr int32_t ITEM_SPAWN_TICK = 5;
constexpr int32_t ITEM_RESERVED0 = 6;
constexpr int32_t ITEM_RESERVED1 = 7;

constexpr int32_t GRID_STRIDE = 4;
constexpr int32_t GRID_CELL_TYPE = 0;
constexpr int32_t GRID_BLOCKER_FLAGS = 1;
constexpr int32_t GRID_OCCUPANT_FLAGS = 2;
constexpr int32_t GRID_RESERVED0 = 3;
} // namespace qqt::packed_schema
