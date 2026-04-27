#include "native_movement_kernel.h"

#include <algorithm>
#include <cstdint>
#include <unordered_map>
#include <vector>

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

using namespace godot;

namespace {
constexpr const char *KERNEL_VERSION = "kernel_v1";

constexpr int32_t CELL_UNITS = 1000;
constexpr int32_t HALF_CELL_UNITS = CELL_UNITS / 2;
constexpr int32_t DEFAULT_TURN_SNAP_WINDOW_UNITS = 250;
constexpr int32_t DEFAULT_PASS_ABSORB_WINDOW_UNITS = 250;
constexpr int64_t WIRE_VERSION = 1;
constexpr int32_t MOVEMENT_PAYLOAD_MAGIC = 1297371473;

struct Vec2i {
    int32_t x = 0;
    int32_t y = 0;
};

struct PlayerRecord {
    int32_t player_id = -1;
    int32_t player_slot = 0;
    int32_t alive = 0;
    int32_t life_state = 0;
    int32_t cell_x = 0;
    int32_t cell_y = 0;
    int32_t offset_x = 0;
    int32_t offset_y = 0;
    int32_t last_non_zero_move_x = 0;
    int32_t last_non_zero_move_y = 0;
    int32_t facing = 0;
    int32_t move_state = 0;
    int32_t move_phase_ticks = 0;
    int32_t speed_level = 1;
    int32_t command_move_x = 0;
    int32_t command_move_y = 0;
};

struct BubbleRecord {
    int32_t bubble_id = -1;
    int32_t alive = 0;
    int32_t cell_x = 0;
    int32_t cell_y = 0;
    int32_t ignore_count = 0;
    int32_t ignore_values_offset = 0;
};

struct GridRecord {
    int32_t cell_x = 0;
    int32_t cell_y = 0;
    int32_t tile_block_move = 0;
    int32_t bubble_id = -1;
};

enum RailType {
    RAIL_FREE = 0,
    RAIL_HORIZONTAL = 1,
    RAIL_VERTICAL = 2,
    RAIL_CENTER_PIVOT = 3,
};

Dictionary make_empty_result() {
    Dictionary result;
    result["version"] = WIRE_VERSION;
    result["player_updates"] = Array();
    result["blocked_events"] = Array();
    result["cell_changes"] = Array();
    result["bubble_ignore_removals"] = Array();
    return result;
}

int32_t floor_div_cell_units(int32_t value) {
    if (value >= 0) {
        return value / CELL_UNITS;
    }
    return -static_cast<int32_t>(((-value) + CELL_UNITS - 1) / CELL_UNITS);
}

int32_t get_cell_center_abs(int32_t cell) {
    return (cell * CELL_UNITS) + HALF_CELL_UNITS;
}

Vec2i get_abs_pos(const PlayerRecord &player) {
    return Vec2i{get_cell_center_abs(player.cell_x) + player.offset_x, get_cell_center_abs(player.cell_y) + player.offset_y};
}

int32_t abs_to_cell(int32_t abs_value) {
    return floor_div_cell_units(abs_value);
}

void write_player_abs_pos(PlayerRecord &player, int32_t abs_x, int32_t abs_y) {
    const int32_t cell_x = abs_to_cell(abs_x);
    const int32_t cell_y = abs_to_cell(abs_y);
    player.cell_x = cell_x;
    player.cell_y = cell_y;
    player.offset_x = abs_x - get_cell_center_abs(cell_x);
    player.offset_y = abs_y - get_cell_center_abs(cell_y);
}

Vec2i get_foot_cell(const PlayerRecord &player) {
    const Vec2i abs_pos = get_abs_pos(player);
    return Vec2i{abs_to_cell(abs_pos.x), abs_to_cell(abs_pos.y)};
}

int32_t sanitize_axis(int32_t value) {
    return std::max(-1, std::min(1, value));
}

bool in_bounds(int32_t width, int32_t height, int32_t x, int32_t y) {
    return x >= 0 && y >= 0 && x < width && y < height;
}

int64_t make_cell_key(int32_t x, int32_t y) {
    return (static_cast<int64_t>(x) << 32) ^ static_cast<uint32_t>(y);
}

int32_t resolve_ticks_per_step(int32_t speed_level) {
    if (speed_level <= 1) {
        return 3;
    }
    if (speed_level == 2) {
        return 2;
    }
    return 1;
}

int32_t resolve_rail_from_neighbors(bool up_blocked, bool down_blocked, bool left_blocked, bool right_blocked) {
    const bool horizontal_rail = up_blocked && down_blocked;
    const bool vertical_rail = left_blocked && right_blocked;
    if (horizontal_rail && vertical_rail) {
        return RAIL_CENTER_PIVOT;
    }
    if (horizontal_rail) {
        return RAIL_HORIZONTAL;
    }
    if (vertical_rail) {
        return RAIL_VERTICAL;
    }
    return RAIL_FREE;
}

bool requires_center_for_vertical_turn(int32_t rail) {
    return rail == RAIL_HORIZONTAL || rail == RAIL_CENTER_PIVOT;
}

bool requires_center_for_horizontal_turn(int32_t rail) {
    return rail == RAIL_VERTICAL || rail == RAIL_CENTER_PIVOT;
}

struct KernelContext {
    int32_t width = 0;
    int32_t height = 0;
    int32_t movement_step_units = 0;
    int32_t turn_snap_window_units = DEFAULT_TURN_SNAP_WINDOW_UNITS;
    int32_t pass_absorb_window_units = DEFAULT_PASS_ABSORB_WINDOW_UNITS;
    std::vector<GridRecord> grid_records;
    std::unordered_map<int32_t, BubbleRecord> bubbles_by_id;
    std::vector<int32_t> bubble_ignore_values;
};

const GridRecord *find_grid_record(const KernelContext &ctx, int32_t x, int32_t y) {
    if (!in_bounds(ctx.width, ctx.height, x, y)) {
        return nullptr;
    }
    const int64_t index = static_cast<int64_t>(y) * ctx.width + x;
    if (index < 0 || index >= static_cast<int64_t>(ctx.grid_records.size())) {
        return nullptr;
    }
    return &ctx.grid_records[static_cast<size_t>(index)];
}

bool bubble_has_ignore(const KernelContext &ctx, const BubbleRecord &bubble, int32_t player_id) {
    const int32_t start = bubble.ignore_values_offset;
    const int32_t end = start + bubble.ignore_count;
    if (start < 0 || end > static_cast<int32_t>(ctx.bubble_ignore_values.size())) {
        return false;
    }
    for (int32_t index = start; index < end; ++index) {
        if (ctx.bubble_ignore_values[static_cast<size_t>(index)] == player_id) {
            return true;
        }
    }
    return false;
}

bool is_bubble_blocking_for_player(const KernelContext &ctx, int32_t player_id, int32_t bubble_id) {
    const auto found = ctx.bubbles_by_id.find(bubble_id);
    if (found == ctx.bubbles_by_id.end()) {
        return false;
    }
    const BubbleRecord &bubble = found->second;
    if (bubble.alive == 0) {
        return false;
    }
    return !bubble_has_ignore(ctx, bubble, player_id);
}

bool is_move_blocked_for_player(const KernelContext &ctx, int32_t player_id, int32_t x, int32_t y) {
    const GridRecord *grid = find_grid_record(ctx, x, y);
    if (grid == nullptr) {
        return true;
    }
    if (grid->tile_block_move != 0) {
        return true;
    }
    return grid->bubble_id != -1 && is_bubble_blocking_for_player(ctx, player_id, grid->bubble_id);
}

bool is_transition_blocked_for_player(const KernelContext &ctx, int32_t player_id, int32_t from_x, int32_t from_y, int32_t to_x, int32_t to_y) {
    if (from_x == to_x && from_y == to_y) {
        return false;
    }
    return is_move_blocked_for_player(ctx, player_id, to_x, to_y);
}

int32_t get_player_rail_constraint(const KernelContext &ctx, int32_t player_id, int32_t cell_x, int32_t cell_y) {
    return resolve_rail_from_neighbors(
        is_move_blocked_for_player(ctx, player_id, cell_x, cell_y - 1),
        is_move_blocked_for_player(ctx, player_id, cell_x, cell_y + 1),
        is_move_blocked_for_player(ctx, player_id, cell_x - 1, cell_y),
        is_move_blocked_for_player(ctx, player_id, cell_x + 1, cell_y)
    );
}

bool try_apply_turn_snap(PlayerRecord &player, const Vec2i &foot_cell, int32_t rail, int32_t move_x, int32_t move_y, int32_t turn_snap_window_units) {
    if (rail == RAIL_CENTER_PIVOT) {
        return false;
    }

    Vec2i abs_pos = get_abs_pos(player);
    if (requires_center_for_vertical_turn(rail) && move_y != 0) {
        if (std::abs(player.offset_x) > turn_snap_window_units) {
            return false;
        }
        abs_pos.x = get_cell_center_abs(foot_cell.x);
    }

    if (requires_center_for_horizontal_turn(rail) && move_x != 0) {
        if (std::abs(player.offset_y) > turn_snap_window_units) {
            return false;
        }
        abs_pos.y = get_cell_center_abs(foot_cell.y);
    }

    write_player_abs_pos(player, abs_pos.x, abs_pos.y);
    return true;
}

Vec2i clamp_abs_to_blocked_axis_limit(const Vec2i &abs_pos, const Vec2i &foot_cell, int32_t move_x, int32_t move_y) {
    Vec2i clamped = abs_pos;
    if (move_x > 0) {
        clamped.x = std::min(clamped.x, get_cell_center_abs(foot_cell.x));
    } else if (move_x < 0) {
        clamped.x = std::max(clamped.x, get_cell_center_abs(foot_cell.x));
    } else if (move_y > 0) {
        clamped.y = std::min(clamped.y, get_cell_center_abs(foot_cell.y));
    } else if (move_y < 0) {
        clamped.y = std::max(clamped.y, get_cell_center_abs(foot_cell.y));
    }
    return clamped;
}

bool is_overlapping_blocked_cell(const Vec2i &abs_pos, const Vec2i &blocked_cell) {
    return std::abs(abs_pos.x - get_cell_center_abs(blocked_cell.x)) < CELL_UNITS
        && std::abs(abs_pos.y - get_cell_center_abs(blocked_cell.y)) < CELL_UNITS;
}

Dictionary find_overlap_blocked_cell(
    const KernelContext &ctx,
    int32_t player_id,
    const Vec2i &abs_pos,
    const Vec2i &foot_cell,
    const Vec2i &target_cell,
    int32_t move_x,
    int32_t move_y
) {
    Array candidates;
    if (move_x != 0) {
        candidates.append(Vector2i(target_cell.x, foot_cell.y - 1));
        candidates.append(Vector2i(target_cell.x, foot_cell.y + 1));
    } else if (move_y != 0) {
        candidates.append(Vector2i(foot_cell.x - 1, target_cell.y));
        candidates.append(Vector2i(foot_cell.x + 1, target_cell.y));
    }

    Dictionary result;
    result["found"] = false;
    result["cell"] = Vector2i();
    for (int32_t index = 0; index < candidates.size(); ++index) {
        const Vector2i blocked_cell = candidates[index];
        if (!is_transition_blocked_for_player(ctx, player_id, foot_cell.x, foot_cell.y, blocked_cell.x, blocked_cell.y)) {
            continue;
        }
        if (!is_overlapping_blocked_cell(abs_pos, Vec2i{blocked_cell.x, blocked_cell.y})) {
            continue;
        }
        result["found"] = true;
        result["cell"] = blocked_cell;
        return result;
    }
    return result;
}

bool crosses_cell_boundary(const Vec2i &abs_pos, const Vec2i &foot_cell, int32_t move_x, int32_t move_y) {
    if (move_x > 0) {
        return abs_pos.x >= ((foot_cell.x + 1) * CELL_UNITS);
    }
    if (move_x < 0) {
        return abs_pos.x < (foot_cell.x * CELL_UNITS);
    }
    if (move_y > 0) {
        return abs_pos.y >= ((foot_cell.y + 1) * CELL_UNITS);
    }
    if (move_y < 0) {
        return abs_pos.y < (foot_cell.y * CELL_UNITS);
    }
    return false;
}

Vec2i try_apply_lane_center_snap(
    const Vec2i &current_abs_pos,
    const Vec2i &tentative_abs_pos,
    const Vec2i &foot_cell,
    int32_t move_x,
    int32_t move_y,
    int32_t pass_absorb_window_units
) {
    Vec2i snapped = tentative_abs_pos;
    if (move_x != 0) {
        const int32_t offset_y = current_abs_pos.y - get_cell_center_abs(foot_cell.y);
        if (offset_y != 0 && std::abs(offset_y) <= pass_absorb_window_units) {
            snapped.y = get_cell_center_abs(foot_cell.y);
        }
    } else if (move_y != 0) {
        const int32_t offset_x = current_abs_pos.x - get_cell_center_abs(foot_cell.x);
        if (offset_x != 0 && std::abs(offset_x) <= pass_absorb_window_units) {
            snapped.x = get_cell_center_abs(foot_cell.x);
        }
    }
    return snapped;
}

Dictionary try_move_along_axis(
    const KernelContext &ctx,
    int32_t player_id,
    const PlayerRecord &player,
    int32_t move_x,
    int32_t move_y,
    int32_t step_units,
    int32_t total_units
) {
    const Vec2i abs_pos = get_abs_pos(player);
    const Vec2i foot_cell = get_foot_cell(player);
    const Vec2i target_cell{foot_cell.x + move_x, foot_cell.y + move_y};
    const bool direct_target_blocked = is_transition_blocked_for_player(ctx, player_id, foot_cell.x, foot_cell.y, target_cell.x, target_cell.y);
    const Vec2i tentative{abs_pos.x + (move_x * step_units), abs_pos.y + (move_y * step_units)};

    Dictionary result;
    result["blocked"] = false;
    result["blocked_cell"] = Vector2i(target_cell.x, target_cell.y);
    result["abs_pos"] = Vector2i(tentative.x, tentative.y);

    if (direct_target_blocked) {
        const Vec2i clamped = clamp_abs_to_blocked_axis_limit(tentative, foot_cell, move_x, move_y);
        result["abs_pos"] = Vector2i(clamped.x, clamped.y);
        result["blocked"] = clamped.x == abs_pos.x && clamped.y == abs_pos.y;
        return result;
    }

    const Dictionary blocked_hit = find_overlap_blocked_cell(ctx, player_id, tentative, foot_cell, target_cell, move_x, move_y);
    if (!static_cast<bool>(blocked_hit.get("found", false))) {
        return result;
    }

    const Vec2i snapped = try_apply_lane_center_snap(abs_pos, tentative, foot_cell, move_x, move_y, ctx.pass_absorb_window_units);
    const Dictionary snapped_hit = find_overlap_blocked_cell(ctx, player_id, snapped, foot_cell, target_cell, move_x, move_y);
    if (snapped.x == tentative.x && snapped.y == tentative.y) {
        result["abs_pos"] = Vector2i(abs_pos.x, abs_pos.y);
        result["blocked"] = true;
        result["blocked_cell"] = blocked_hit.get("cell", Vector2i());
        return result;
    }
    if (static_cast<bool>(snapped_hit.get("found", false))) {
        result["abs_pos"] = Vector2i(abs_pos.x, abs_pos.y);
        result["blocked"] = true;
        result["blocked_cell"] = snapped_hit.get("cell", Vector2i());
        return result;
    }

    result["abs_pos"] = Vector2i(snapped.x, snapped.y);
    if (!crosses_cell_boundary(snapped, foot_cell, move_x, move_y)) {
        return result;
    }
    return result;
}

bool is_player_overlapping_bubble(const PlayerRecord &player, const BubbleRecord &bubble) {
    const Vec2i player_abs = get_abs_pos(player);
    return std::abs(player_abs.x - get_cell_center_abs(bubble.cell_x)) < CELL_UNITS
        && std::abs(player_abs.y - get_cell_center_abs(bubble.cell_y)) < CELL_UNITS;
}

bool read_i32(const PackedByteArray &buffer, int32_t &cursor, int32_t &value) {
    if (cursor + 4 > buffer.size()) {
        return false;
    }
    const uint8_t *data = buffer.ptr();
    const uint32_t bits = static_cast<uint32_t>(data[cursor])
        | (static_cast<uint32_t>(data[cursor + 1]) << 8)
        | (static_cast<uint32_t>(data[cursor + 2]) << 16)
        | (static_cast<uint32_t>(data[cursor + 3]) << 24);
    value = static_cast<int32_t>(bits);
    cursor += 4;
    return true;
}

void append_i32(PackedByteArray &buffer, int32_t value) {
    const uint32_t bits = static_cast<uint32_t>(value);
    buffer.append(static_cast<uint8_t>(bits & 0xFF));
    buffer.append(static_cast<uint8_t>((bits >> 8) & 0xFF));
    buffer.append(static_cast<uint8_t>((bits >> 16) & 0xFF));
    buffer.append(static_cast<uint8_t>((bits >> 24) & 0xFF));
}

void append_i32_array(PackedByteArray &buffer, const PackedInt32Array &values) {
    append_i32(buffer, values.size());
    const int32_t *data = values.ptr();
    for (int32_t index = 0; index < values.size(); ++index) {
        append_i32(buffer, data[index]);
    }
}

bool read_i32_array(const PackedByteArray &buffer, int32_t &cursor, PackedInt32Array &values) {
    int32_t count = 0;
    if (!read_i32(buffer, cursor, count) || count < 0) {
        return false;
    }
    if (cursor + (count * 4) > buffer.size()) {
        return false;
    }
    values.resize(count);
    for (int32_t index = 0; index < count; ++index) {
        int32_t value = 0;
        if (!read_i32(buffer, cursor, value)) {
            return false;
        }
        values.set(index, value);
    }
    return true;
}

bool decode_binary_input(
    const PackedByteArray &input_blob,
    PackedInt32Array &players,
    PackedInt32Array &bubbles,
    PackedInt32Array &ignore_values,
    PackedInt32Array &blocked_grid,
    int32_t &movement_step_units,
    int32_t &turn_snap_window_units,
    int32_t &pass_absorb_window_units
) {
    int32_t cursor = 0;
    int32_t magic = 0;
    int32_t version = 0;
    if (!read_i32(input_blob, cursor, magic) || magic != MOVEMENT_PAYLOAD_MAGIC) {
        return false;
    }
    if (!read_i32(input_blob, cursor, version) || version != static_cast<int32_t>(WIRE_VERSION)) {
        return false;
    }
    if (
        !read_i32(input_blob, cursor, movement_step_units)
        || !read_i32(input_blob, cursor, turn_snap_window_units)
        || !read_i32(input_blob, cursor, pass_absorb_window_units)
        || !read_i32_array(input_blob, cursor, players)
        || !read_i32_array(input_blob, cursor, bubbles)
        || !read_i32_array(input_blob, cursor, ignore_values)
        || !read_i32_array(input_blob, cursor, blocked_grid)
    ) {
        return false;
    }
    return cursor == input_blob.size();
}
} // namespace

void QQTNativeMovementKernel::_bind_methods() {
    ClassDB::bind_method(D_METHOD("get_kernel_version"), &QQTNativeMovementKernel::get_kernel_version);
    ClassDB::bind_method(D_METHOD("step_players", "input_blob"), &QQTNativeMovementKernel::step_players);
    ClassDB::bind_method(
        D_METHOD(
            "step_players_packed",
            "players",
            "bubbles",
            "ignore_values",
            "blocked_grid",
            "movement_step_units",
            "turn_snap_window_units",
            "pass_absorb_window_units"
        ),
        &QQTNativeMovementKernel::step_players_packed
    );
}

String QQTNativeMovementKernel::get_kernel_version() const {
    return String(KERNEL_VERSION);
}

PackedByteArray QQTNativeMovementKernel::step_players_packed(
    const PackedInt32Array &players,
    const PackedInt32Array &bubbles,
    const PackedInt32Array &ignore_values,
    const PackedInt32Array &blocked_grid,
    int32_t movement_step_units,
    int32_t turn_snap_window_units,
    int32_t pass_absorb_window_units
) const {
    PackedByteArray input_blob;
    const int32_t total_i32_count = 5
        + 1 + players.size()
        + 1 + bubbles.size()
        + 1 + ignore_values.size()
        + 1 + blocked_grid.size();
    input_blob.resize(total_i32_count * 4);
    input_blob.clear();
    append_i32(input_blob, MOVEMENT_PAYLOAD_MAGIC);
    append_i32(input_blob, static_cast<int32_t>(WIRE_VERSION));
    append_i32(input_blob, movement_step_units);
    append_i32(input_blob, turn_snap_window_units);
    append_i32(input_blob, pass_absorb_window_units);
    append_i32_array(input_blob, players);
    append_i32_array(input_blob, bubbles);
    append_i32_array(input_blob, ignore_values);
    append_i32_array(input_blob, blocked_grid);
    return step_players(input_blob);
}

PackedByteArray QQTNativeMovementKernel::step_players(const PackedByteArray &input_blob) const {
    Dictionary result = make_empty_result();
    if (input_blob.is_empty()) {
        return UtilityFunctions::var_to_bytes(result);
    }

    PackedInt32Array players;
    PackedInt32Array bubbles;
    PackedInt32Array ignore_values;
    PackedInt32Array blocked_grid;
    int32_t movement_step_units = 0;
    int32_t turn_snap_window_units = DEFAULT_TURN_SNAP_WINDOW_UNITS;
    int32_t pass_absorb_window_units = DEFAULT_PASS_ABSORB_WINDOW_UNITS;
    if (!decode_binary_input(
        input_blob,
        players,
        bubbles,
        ignore_values,
        blocked_grid,
        movement_step_units,
        turn_snap_window_units,
        pass_absorb_window_units
    )) {
        const Variant input_variant = UtilityFunctions::bytes_to_var(input_blob);
        if (input_variant.get_type() != Variant::DICTIONARY) {
            return UtilityFunctions::var_to_bytes(result);
        }

        const Dictionary payload = input_variant;
        if (static_cast<int64_t>(payload.get("version", 0)) != WIRE_VERSION) {
            return UtilityFunctions::var_to_bytes(result);
        }
        const Variant player_variant = payload.get("player_records", PackedInt32Array());
        const Variant bubble_variant = payload.get("bubble_records", PackedInt32Array());
        const Variant ignore_variant = payload.get("bubble_ignore_values", PackedInt32Array());
        const Variant blocked_variant = payload.get("blocked_grid_records", PackedInt32Array());
        const Variant tuning_variant = payload.get("tuning", Dictionary());
        if (
            player_variant.get_type() != Variant::PACKED_INT32_ARRAY
            || bubble_variant.get_type() != Variant::PACKED_INT32_ARRAY
            || ignore_variant.get_type() != Variant::PACKED_INT32_ARRAY
            || blocked_variant.get_type() != Variant::PACKED_INT32_ARRAY
            || tuning_variant.get_type() != Variant::DICTIONARY
        ) {
            return UtilityFunctions::var_to_bytes(result);
        }

        players = player_variant;
        bubbles = bubble_variant;
        ignore_values = ignore_variant;
        blocked_grid = blocked_variant;
        const Dictionary tuning = tuning_variant;
        movement_step_units = static_cast<int32_t>(static_cast<int64_t>(tuning.get("movement_step_units", 0)));
        turn_snap_window_units = static_cast<int32_t>(static_cast<int64_t>(tuning.get("turn_snap_window_units", DEFAULT_TURN_SNAP_WINDOW_UNITS)));
        pass_absorb_window_units = static_cast<int32_t>(static_cast<int64_t>(tuning.get("pass_absorb_window_units", DEFAULT_PASS_ABSORB_WINDOW_UNITS)));
    }
    const int32_t stride = 16;
    if (players.size() <= 0 || (players.size() % stride) != 0) {
        return UtilityFunctions::var_to_bytes(result);
    }

    KernelContext ctx;
    ctx.movement_step_units = movement_step_units;
    ctx.turn_snap_window_units = turn_snap_window_units;
    ctx.pass_absorb_window_units = pass_absorb_window_units;
    if (ctx.movement_step_units <= 0) {
        return UtilityFunctions::var_to_bytes(result);
    }

    ctx.bubble_ignore_values.resize(static_cast<size_t>(ignore_values.size()));
    for (int32_t index = 0; index < ignore_values.size(); ++index) {
        ctx.bubble_ignore_values[static_cast<size_t>(index)] = ignore_values[index];
    }

    if ((bubbles.size() % 6) != 0 || (blocked_grid.size() % 5) != 0) {
        return UtilityFunctions::var_to_bytes(result);
    }

    for (int32_t index = 0; index < bubbles.size(); index += 6) {
        BubbleRecord bubble;
        bubble.bubble_id = bubbles[index];
        bubble.alive = bubbles[index + 1];
        bubble.cell_x = bubbles[index + 2];
        bubble.cell_y = bubbles[index + 3];
        bubble.ignore_count = bubbles[index + 4];
        bubble.ignore_values_offset = bubbles[index + 5];
        ctx.bubbles_by_id[bubble.bubble_id] = bubble;
    }

    int32_t max_x = -1;
    int32_t max_y = -1;
    for (int32_t index = 0; index < blocked_grid.size(); index += 5) {
        max_x = std::max(max_x, blocked_grid[index]);
        max_y = std::max(max_y, blocked_grid[index + 1]);
    }
    ctx.width = max_x + 1;
    ctx.height = max_y + 1;
    if (ctx.width <= 0 || ctx.height <= 0) {
        return UtilityFunctions::var_to_bytes(result);
    }
    ctx.grid_records.resize(static_cast<size_t>(ctx.width * ctx.height));
    for (int32_t index = 0; index < blocked_grid.size(); index += 5) {
        GridRecord grid;
        grid.cell_x = blocked_grid[index];
        grid.cell_y = blocked_grid[index + 1];
        grid.tile_block_move = blocked_grid[index + 2];
        grid.bubble_id = blocked_grid[index + 3];
        const int64_t flat_index = static_cast<int64_t>(grid.cell_y) * ctx.width + grid.cell_x;
        if (flat_index < 0 || flat_index >= static_cast<int64_t>(ctx.grid_records.size())) {
            continue;
        }
        ctx.grid_records[static_cast<size_t>(flat_index)] = grid;
    }

    Array updates;
    Array blocked_events;
    Array cell_changes;
    Array bubble_ignore_removals;
    const int32_t *values = players.ptr();
    for (int32_t i = 0; i < players.size(); i += stride) {
        PlayerRecord player;
        player.player_id = values[i];
        player.player_slot = values[i + 1];
        player.alive = values[i + 2];
        player.life_state = values[i + 3];
        player.cell_x = values[i + 4];
        player.cell_y = values[i + 5];
        player.offset_x = values[i + 6];
        player.offset_y = values[i + 7];
        player.last_non_zero_move_x = values[i + 8];
        player.last_non_zero_move_y = values[i + 9];
        player.facing = values[i + 10];
        player.move_state = values[i + 11];
        player.move_phase_ticks = values[i + 12];
        player.speed_level = values[i + 13];
        player.command_move_x = sanitize_axis(values[i + 14]);
        player.command_move_y = sanitize_axis(values[i + 15]);
        if (player.command_move_x != 0 && player.command_move_y != 0) {
            player.command_move_x = 0;
            player.command_move_y = 0;
        }

        const Vec2i old_foot_cell = get_foot_cell(player);
        bool blocked = false;
        bool turn_only = false;
        Vec2i blocked_cell = old_foot_cell;

        if (player.command_move_x == 0 && player.command_move_y == 0) {
            player.move_phase_ticks = 0;
            player.move_state = 0;
        } else {
            player.last_non_zero_move_x = player.command_move_x;
            player.last_non_zero_move_y = player.command_move_y;
            if (player.command_move_y > 0) {
                player.facing = 1;
            } else if (player.command_move_y < 0) {
                player.facing = 0;
            } else if (player.command_move_x > 0) {
                player.facing = 3;
            } else if (player.command_move_x < 0) {
                player.facing = 2;
            }

            const int32_t required_ticks = std::max(resolve_ticks_per_step(player.speed_level), 1);
            player.move_phase_ticks += 1;
            const int32_t step_count = player.move_phase_ticks / required_ticks;
            player.move_phase_ticks = player.move_phase_ticks % required_ticks;

            for (int32_t step_index = 0; step_index < step_count; ++step_index) {
                const Vec2i foot_cell = get_foot_cell(player);
                const Vec2i target_cell{foot_cell.x + player.command_move_x, foot_cell.y + player.command_move_y};
                const bool direct_target_blocked = is_transition_blocked_for_player(
                    ctx,
                    player.player_id,
                    foot_cell.x,
                    foot_cell.y,
                    target_cell.x,
                    target_cell.y
                );
                const int32_t rail = get_player_rail_constraint(ctx, player.player_id, foot_cell.x, foot_cell.y);
                if (!direct_target_blocked && !try_apply_turn_snap(
                    player,
                    foot_cell,
                    rail,
                    player.command_move_x,
                    player.command_move_y,
                    ctx.turn_snap_window_units
                )) {
                    turn_only = true;
                    break;
                }

                const Dictionary move_result = try_move_along_axis(
                    ctx,
                    player.player_id,
                    player,
                    player.command_move_x,
                    player.command_move_y,
                    ctx.movement_step_units,
                    ctx.movement_step_units
                );
                const Vector2i resolved_abs_pos = move_result.get("abs_pos", Vector2i());
                write_player_abs_pos(player, resolved_abs_pos.x, resolved_abs_pos.y);
                if (static_cast<bool>(move_result.get("blocked", false))) {
                    blocked = true;
                    const Vector2i raw_blocked_cell = move_result.get("blocked_cell", Vector2i());
                    blocked_cell = Vec2i{raw_blocked_cell.x, raw_blocked_cell.y};
                    break;
                }
            }

            if (turn_only) {
                player.move_state = 4;
            } else if (blocked) {
                player.move_state = 2;
            } else {
                player.move_state = 1;
            }
        }

        const Vec2i new_foot_cell = get_foot_cell(player);
        if (old_foot_cell.x != new_foot_cell.x || old_foot_cell.y != new_foot_cell.y) {
            Dictionary cell_change;
            cell_change["player_id"] = player.player_id;
            cell_change["from_cell_x"] = old_foot_cell.x;
            cell_change["from_cell_y"] = old_foot_cell.y;
            cell_change["to_cell_x"] = new_foot_cell.x;
            cell_change["to_cell_y"] = new_foot_cell.y;
            cell_changes.append(cell_change);
        }

        if (blocked) {
            Dictionary blocked_event;
            blocked_event["player_id"] = player.player_id;
            blocked_event["from_cell_x"] = old_foot_cell.x;
            blocked_event["from_cell_y"] = old_foot_cell.y;
            blocked_event["blocked_cell_x"] = blocked_cell.x;
            blocked_event["blocked_cell_y"] = blocked_cell.y;
            blocked_events.append(blocked_event);
        }

        std::vector<int32_t> bubble_ids;
        bubble_ids.reserve(ctx.bubbles_by_id.size());
        for (const auto &entry : ctx.bubbles_by_id) {
            bubble_ids.push_back(entry.first);
        }
        std::sort(bubble_ids.begin(), bubble_ids.end());
        for (const int32_t bubble_id : bubble_ids) {
            const BubbleRecord &bubble = ctx.bubbles_by_id[bubble_id];
            if (bubble.alive == 0 || !bubble_has_ignore(ctx, bubble, player.player_id)) {
                continue;
            }
            if (is_player_overlapping_bubble(player, bubble)) {
                continue;
            }
            Dictionary ignore_removal;
            ignore_removal["bubble_id"] = bubble_id;
            ignore_removal["player_id"] = player.player_id;
            bubble_ignore_removals.append(ignore_removal);
        }

        Dictionary player_update;
        player_update["player_id"] = player.player_id;
        player_update["cell_x"] = player.cell_x;
        player_update["cell_y"] = player.cell_y;
        player_update["offset_x"] = player.offset_x;
        player_update["offset_y"] = player.offset_y;
        player_update["facing"] = player.facing;
        player_update["move_state"] = player.move_state;
        player_update["move_phase_ticks"] = player.move_phase_ticks;
        player_update["last_non_zero_move_x"] = player.last_non_zero_move_x;
        player_update["last_non_zero_move_y"] = player.last_non_zero_move_y;
        updates.append(player_update);
    }

    result["player_updates"] = updates;
    result["blocked_events"] = blocked_events;
    result["cell_changes"] = cell_changes;
    result["bubble_ignore_removals"] = bubble_ignore_removals;
    result["version"] = WIRE_VERSION;
    return UtilityFunctions::var_to_bytes(result);
}
