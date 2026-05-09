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
constexpr const char *KERNEL_VERSION = "native_kernel_v1";

constexpr int32_t CELL_UNITS = 1000;
constexpr int32_t HALF_CELL_UNITS = CELL_UNITS / 2;
constexpr int32_t DEFAULT_TURN_SNAP_WINDOW_UNITS = 250;
constexpr int32_t DEFAULT_PASS_ABSORB_WINDOW_UNITS = 250;
constexpr int64_t WIRE_VERSION = 3;
constexpr int32_t MOVEMENT_PAYLOAD_MAGIC = 1297371473;
constexpr int32_t SPEED_TABLE[] = {70, 82, 94, 106, 118, 130, 142, 154, 166};

// Phase 状态机：与 GD 端 BubblePassPhase.Phase 对齐。
constexpr int32_t PHASE_A = 0;
constexpr int32_t PHASE_B = 1;
constexpr int32_t PHASE_C = 2;

// 每条 phase 在 phase_values 数组中占的整数个数：
// [player_id, phase_x, sign_x, phase_y, sign_y]
constexpr int32_t PHASE_FIELDS_PER_ENTRY = 5;

// Bubble 记录 stride（与 native_movement_bridge.gd::_pack_bubble_records 对齐）
constexpr int32_t BUBBLE_RECORD_STRIDE = 7;

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
    int32_t move_remainder_units = 0;
    int32_t speed_level = 1;
    int32_t command_move_x = 0;
    int32_t command_move_y = 0;
};

struct BubbleRecord {
    int32_t bubble_id = -1;
    int32_t alive = 0;
    int32_t cell_x = 0;
    int32_t cell_y = 0;
    int32_t footprint_cells = 1;
    int32_t phase_count = 0;
    int32_t phase_values_offset = 0;
};

struct PhaseRecord {
    int32_t player_id = -1;
    int32_t phase_x = PHASE_A;
    int32_t sign_x = 0;
    int32_t phase_y = PHASE_A;
    int32_t sign_y = 0;
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
    result["bubble_phase_updates"] = Array();
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

int32_t resolve_movement_units_per_tick(int32_t speed_level) {
    const int32_t max_level = static_cast<int32_t>(sizeof(SPEED_TABLE) / sizeof(SPEED_TABLE[0]));
    const int32_t clamped_level = std::max(1, std::min(max_level, speed_level));
    return SPEED_TABLE[clamped_level - 1];
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

int32_t sign_of(int32_t value) {
    if (value > 0) return 1;
    if (value < 0) return -1;
    return 1;
}

int32_t footprint_size(int32_t footprint_cells) {
    int32_t s = 1;
    while (s * s < footprint_cells) {
        ++s;
    }
    return std::max(1, s);
}

struct KernelContext {
    int32_t width = 0;
    int32_t height = 0;
    int32_t movement_substep_units = 0;
    int32_t turn_snap_window_units = DEFAULT_TURN_SNAP_WINDOW_UNITS;
    int32_t pass_absorb_window_units = DEFAULT_PASS_ABSORB_WINDOW_UNITS;
    int32_t bubble_overlap_center_mode = 0;
    int32_t bubble_phase_init_mode = 0;
    std::vector<GridRecord> grid_records;
    std::unordered_map<int32_t, BubbleRecord> bubbles_by_id;
    std::vector<PhaseRecord> phase_table;  // 解码后的 phase 列表，按 bubble.phase_values_offset/PHASE_FIELDS_PER_ENTRY 索引
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

const PhaseRecord *find_phase(const KernelContext &ctx, const BubbleRecord &bubble, int32_t player_id) {
    const int32_t start_index = bubble.phase_values_offset / PHASE_FIELDS_PER_ENTRY;
    const int32_t end_index = start_index + bubble.phase_count;
    if (start_index < 0 || end_index > static_cast<int32_t>(ctx.phase_table.size())) {
        return nullptr;
    }
    for (int32_t i = start_index; i < end_index; ++i) {
        if (ctx.phase_table[static_cast<size_t>(i)].player_id == player_id) {
            return &ctx.phase_table[static_cast<size_t>(i)];
        }
    }
    return nullptr;
}

// 根据 mode 选择泡泡参考中心：
//   0 = 单格中心 (bubble.cell_x/cell_y)
//   1 = footprint 内距 candidate 最近的格中心（曼哈顿距离最近）
Vec2i resolve_bubble_reference_center(const KernelContext &ctx, const BubbleRecord &bubble, const Vec2i &candidate) {
    const Vec2i base_center{get_cell_center_abs(bubble.cell_x), get_cell_center_abs(bubble.cell_y)};
    if (ctx.bubble_overlap_center_mode == 0) {
        return base_center;
    }
    Vec2i best_center = base_center;
    int32_t best_dist = std::abs(candidate.x - best_center.x) + std::abs(candidate.y - best_center.y);
    const int32_t size = footprint_size(bubble.footprint_cells);
    int32_t remaining = std::max(1, bubble.footprint_cells);
    for (int32_t dy = 0; dy < size && remaining > 0; ++dy) {
        for (int32_t dx = 0; dx < size && remaining > 0; ++dx) {
            const Vec2i cell{
                get_cell_center_abs(bubble.cell_x + dx),
                get_cell_center_abs(bubble.cell_y + dy)
            };
            const int32_t d = std::abs(candidate.x - cell.x) + std::abs(candidate.y - cell.y);
            if (d < best_dist) {
                best_dist = d;
                best_center = cell;
            }
            --remaining;
        }
    }
    return best_center;
}

// 单轴是否违反 phase 约束：A 自由；B(s) 要求 d*s >= M/2；C(s) 要求 d*s >= M。
bool axis_violates(int32_t axis_phase, int32_t axis_sign, int32_t d) {
    if (axis_phase == PHASE_A) {
        return false;
    }
    const int32_t signed_d = d * axis_sign;
    if (axis_phase == PHASE_B) {
        return signed_d < HALF_CELL_UNITS;
    }
    return signed_d < CELL_UNITS;
}

// 候选位置 + phase 推断（懒初始化模式下使用）
PhaseRecord compute_lazy_phase(int32_t player_id, int32_t d_x, int32_t d_y) {
    PhaseRecord phase;
    phase.player_id = player_id;
    const int32_t abs_dx = std::abs(d_x);
    const int32_t abs_dy = std::abs(d_y);
    if (abs_dx >= CELL_UNITS) {
        phase.phase_x = PHASE_C;
        phase.sign_x = sign_of(d_x);
    } else if (abs_dx >= HALF_CELL_UNITS) {
        phase.phase_x = PHASE_B;
        phase.sign_x = sign_of(d_x);
    } else {
        phase.phase_x = PHASE_A;
        phase.sign_x = 0;
    }
    if (abs_dy >= CELL_UNITS) {
        phase.phase_y = PHASE_C;
        phase.sign_y = sign_of(d_y);
    } else if (abs_dy >= HALF_CELL_UNITS) {
        phase.phase_y = PHASE_B;
        phase.sign_y = sign_of(d_y);
    } else {
        phase.phase_y = PHASE_A;
        phase.sign_y = 0;
    }
    return phase;
}

bool is_bubble_blocking_at_pos(const KernelContext &ctx, int32_t player_id, int32_t bubble_id, int32_t candidate_x, int32_t candidate_y) {
    const auto found = ctx.bubbles_by_id.find(bubble_id);
    if (found == ctx.bubbles_by_id.end()) {
        return false;
    }
    const BubbleRecord &bubble = found->second;
    if (bubble.alive == 0) {
        return false;
    }
    const Vec2i candidate{candidate_x, candidate_y};
    const Vec2i center = resolve_bubble_reference_center(ctx, bubble, candidate);
    const int32_t d_x = candidate_x - center.x;
    const int32_t d_y = candidate_y - center.y;

    const PhaseRecord *phase = find_phase(ctx, bubble, player_id);
    PhaseRecord lazy_phase;
    if (phase == nullptr) {
        if (ctx.bubble_phase_init_mode == 0) {
            return true;
        }
        lazy_phase = compute_lazy_phase(player_id, d_x, d_y);
        phase = &lazy_phase;
    }

    if (phase->phase_x == PHASE_A && phase->phase_y == PHASE_A) {
        return false;
    }
    if (axis_violates(phase->phase_x, phase->sign_x, d_x)) {
        return true;
    }
    if (axis_violates(phase->phase_y, phase->sign_y, d_y)) {
        return true;
    }
    return false;
}

bool is_move_blocked_for_player_at_pos(const KernelContext &ctx, int32_t player_id, int32_t cell_x, int32_t cell_y, int32_t candidate_x, int32_t candidate_y) {
    const GridRecord *grid = find_grid_record(ctx, cell_x, cell_y);
    if (grid == nullptr) {
        return true;
    }
    if (grid->tile_block_move != 0) {
        return true;
    }
    if (grid->bubble_id == -1) {
        return false;
    }
    return is_bubble_blocking_at_pos(ctx, player_id, grid->bubble_id, candidate_x, candidate_y);
}

bool is_move_blocked_for_player_cell(const KernelContext &ctx, int32_t player_id, int32_t cell_x, int32_t cell_y) {
    // cell-only 包装：用目标格中心当 candidate（用于轨道判定）。
    return is_move_blocked_for_player_at_pos(
        ctx, player_id, cell_x, cell_y,
        get_cell_center_abs(cell_x), get_cell_center_abs(cell_y)
    );
}

bool is_transition_blocked_for_player_at_pos(const KernelContext &ctx, int32_t player_id, int32_t from_x, int32_t from_y, int32_t to_x, int32_t to_y, int32_t candidate_x, int32_t candidate_y) {
    if (from_x == to_x && from_y == to_y) {
        return false;
    }
    return is_move_blocked_for_player_at_pos(ctx, player_id, to_x, to_y, candidate_x, candidate_y);
}

int32_t get_player_rail_constraint(const KernelContext &ctx, int32_t player_id, int32_t cell_x, int32_t cell_y) {
    return resolve_rail_from_neighbors(
        is_move_blocked_for_player_cell(ctx, player_id, cell_x, cell_y - 1),
        is_move_blocked_for_player_cell(ctx, player_id, cell_x, cell_y + 1),
        is_move_blocked_for_player_cell(ctx, player_id, cell_x - 1, cell_y),
        is_move_blocked_for_player_cell(ctx, player_id, cell_x + 1, cell_y)
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

// 仅检查 turn_snap 是否会失败（不写入位置），用于 direct_blocked 路径决策 turn_only。
bool turn_snap_would_fail(const PlayerRecord &player, int32_t rail, int32_t move_x, int32_t move_y, int32_t turn_snap_window_units) {
    if (rail == RAIL_CENTER_PIVOT) {
        return true;
    }
    if (requires_center_for_vertical_turn(rail) && move_y != 0) {
        if (std::abs(player.offset_x) > turn_snap_window_units) {
            return true;
        }
    }
    if (requires_center_for_horizontal_turn(rail) && move_x != 0) {
        if (std::abs(player.offset_y) > turn_snap_window_units) {
            return true;
        }
    }
    return false;
}

int32_t axis_unbounded_sentinel(int32_t move_x, int32_t move_y) {
    if (move_x > 0 || move_y > 0) {
        return 1 << 30;
    }
    return -(1 << 30);
}

int32_t tighten_axis_limit(int32_t current, int32_t candidate, int32_t move_x, int32_t move_y) {
    if (move_x > 0 || move_y > 0) {
        return std::min(current, candidate);
    }
    return std::max(current, candidate);
}

int32_t hard_wall_axis_limit(int32_t target_cell_x, int32_t target_cell_y, int32_t move_x, int32_t move_y) {
    // 物理模型：玩家碰撞框 M×M，中心对齐 abs_pos；墙 cell 碰撞框 M×M，中心对齐 cell_center。
    // 两 M×M 框不重叠条件：|abs_pos - wall_center| >= M。
    // 硬墙 = 永远 phase C：玩家中心距墙中心最小 M。
    if (move_x > 0) return target_cell_x * CELL_UNITS - HALF_CELL_UNITS;
    if (move_x < 0) return (target_cell_x + 1) * CELL_UNITS + HALF_CELL_UNITS;
    if (move_y > 0) return target_cell_y * CELL_UNITS - HALF_CELL_UNITS;
    return (target_cell_y + 1) * CELL_UNITS + HALF_CELL_UNITS;
}

int32_t default_block_sign(int32_t player_axis, int32_t center_axis) {
    if (player_axis > center_axis) return 1;
    if (player_axis < center_axis) return -1;
    return 1;
}

int32_t phase_axis_distance_limit(int32_t center_axis, int32_t sign_axis, int32_t phase_axis, int32_t move_x, int32_t move_y) {
    if (phase_axis == PHASE_A) {
        return axis_unbounded_sentinel(move_x, move_y);
    }
    if (sign_axis == 0) {
        return center_axis;
    }
    const int32_t threshold = (phase_axis == PHASE_B) ? HALF_CELL_UNITS : CELL_UNITS;
    return center_axis + sign_axis * threshold;
}

int32_t bubble_phase_axis_limit(
    const KernelContext &ctx,
    int32_t player_id,
    int32_t bubble_id,
    int32_t candidate_x,
    int32_t candidate_y,
    int32_t move_x,
    int32_t move_y
) {
    const auto found = ctx.bubbles_by_id.find(bubble_id);
    if (found == ctx.bubbles_by_id.end()) {
        return axis_unbounded_sentinel(move_x, move_y);
    }
    const BubbleRecord &bubble = found->second;
    if (bubble.alive == 0) {
        return axis_unbounded_sentinel(move_x, move_y);
    }
    const Vec2i candidate{candidate_x, candidate_y};
    const Vec2i center = resolve_bubble_reference_center(ctx, bubble, candidate);

    const PhaseRecord *phase = find_phase(ctx, bubble, player_id);
    if (phase == nullptr) {
        if (ctx.bubble_phase_init_mode == 0) {
            // 视为 C 阶段完全阻挡
            const int32_t player_axis = (move_x != 0) ? candidate_x : candidate_y;
            const int32_t center_axis = (move_x != 0) ? center.x : center.y;
            const int32_t s = default_block_sign(player_axis, center_axis);
            return phase_axis_distance_limit(center_axis, s, PHASE_C, move_x, move_y);
        }
        return axis_unbounded_sentinel(move_x, move_y);
    }

    if (move_x != 0) {
        return phase_axis_distance_limit(center.x, phase->sign_x, phase->phase_x, move_x, move_y);
    }
    return phase_axis_distance_limit(center.y, phase->sign_y, phase->phase_y, move_x, move_y);
}

// MovementSystem 子步用：综合硬墙 + 泡泡 phase 边界，给出该轴允许到达的最远位置。
// 硬墙：玩家可以滑到 cell 边缘（target_cell 近侧 -1 单位）；
// 泡泡 phase：玩家可以滑到 phase 边界。两种语义一致——都是滑到允许极限。
int32_t resolve_axis_blocking_limit(
    const KernelContext &ctx,
    int32_t player_id,
    int32_t target_cell_x,
    int32_t target_cell_y,
    int32_t /*current_abs_x*/,
    int32_t /*current_abs_y*/,
    int32_t candidate_x,
    int32_t candidate_y,
    int32_t move_x,
    int32_t move_y
) {
    int32_t limit = axis_unbounded_sentinel(move_x, move_y);

    const GridRecord *grid = find_grid_record(ctx, target_cell_x, target_cell_y);
    if (grid == nullptr || grid->tile_block_move != 0) {
        const int32_t hard_limit = hard_wall_axis_limit(target_cell_x, target_cell_y, move_x, move_y);
        limit = tighten_axis_limit(limit, hard_limit, move_x, move_y);
    }

    const int32_t bubble_id = (grid != nullptr) ? grid->bubble_id : -1;
    if (bubble_id != -1) {
        const int32_t bubble_limit = bubble_phase_axis_limit(
            ctx, player_id, bubble_id, candidate_x, candidate_y, move_x, move_y
        );
        limit = tighten_axis_limit(limit, bubble_limit, move_x, move_y);
    }
    return limit;
}

Vec2i clamp_abs_to_axis_limit(const Vec2i &abs_pos, int32_t axis_limit, int32_t move_x, int32_t move_y) {
    Vec2i clamped = abs_pos;
    if (move_x > 0) {
        clamped.x = std::min(clamped.x, axis_limit);
    } else if (move_x < 0) {
        clamped.x = std::max(clamped.x, axis_limit);
    } else if (move_y > 0) {
        clamped.y = std::min(clamped.y, axis_limit);
    } else if (move_y < 0) {
        clamped.y = std::max(clamped.y, axis_limit);
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
        if (!is_transition_blocked_for_player_at_pos(
                ctx, player_id, foot_cell.x, foot_cell.y, blocked_cell.x, blocked_cell.y, abs_pos.x, abs_pos.y)) {
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
    int32_t /*total_units*/
) {
    const Vec2i abs_pos = get_abs_pos(player);
    const Vec2i foot_cell = get_foot_cell(player);
    const Vec2i target_cell{foot_cell.x + move_x, foot_cell.y + move_y};
    const Vec2i tentative{abs_pos.x + (move_x * step_units), abs_pos.y + (move_y * step_units)};
    const bool direct_target_blocked = is_transition_blocked_for_player_at_pos(
        ctx, player_id, foot_cell.x, foot_cell.y, target_cell.x, target_cell.y, tentative.x, tentative.y);

    Dictionary result;
    result["blocked"] = false;
    result["blocked_cell"] = Vector2i(target_cell.x, target_cell.y);
    result["abs_pos"] = Vector2i(tentative.x, tentative.y);

    if (direct_target_blocked) {
        const int32_t axis_limit = resolve_axis_blocking_limit(
            ctx, player_id, target_cell.x, target_cell.y,
            abs_pos.x, abs_pos.y, tentative.x, tentative.y, move_x, move_y
        );
        const Vec2i clamped = clamp_abs_to_axis_limit(tentative, axis_limit, move_x, move_y);
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
    PackedInt32Array &phase_values,
    PackedInt32Array &blocked_grid,
    int32_t &movement_substep_units,
    int32_t &turn_snap_window_units,
    int32_t &pass_absorb_window_units,
    int32_t &bubble_overlap_center_mode,
    int32_t &bubble_phase_init_mode
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
        !read_i32(input_blob, cursor, movement_substep_units)
        || !read_i32(input_blob, cursor, turn_snap_window_units)
        || !read_i32(input_blob, cursor, pass_absorb_window_units)
        || !read_i32(input_blob, cursor, bubble_overlap_center_mode)
        || !read_i32(input_blob, cursor, bubble_phase_init_mode)
        || !read_i32_array(input_blob, cursor, players)
        || !read_i32_array(input_blob, cursor, bubbles)
        || !read_i32_array(input_blob, cursor, phase_values)
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
            "phase_values",
            "blocked_grid",
            "movement_substep_units",
            "turn_snap_window_units",
            "pass_absorb_window_units",
            "bubble_overlap_center_mode",
            "bubble_phase_init_mode"
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
    const PackedInt32Array &phase_values,
    const PackedInt32Array &blocked_grid,
    int32_t movement_substep_units,
    int32_t turn_snap_window_units,
    int32_t pass_absorb_window_units,
    int32_t bubble_overlap_center_mode,
    int32_t bubble_phase_init_mode
) const {
    PackedByteArray input_blob;
    const int32_t total_i32_count = 7
        + 1 + players.size()
        + 1 + bubbles.size()
        + 1 + phase_values.size()
        + 1 + blocked_grid.size();
    input_blob.resize(total_i32_count * 4);
    input_blob.clear();
    append_i32(input_blob, MOVEMENT_PAYLOAD_MAGIC);
    append_i32(input_blob, static_cast<int32_t>(WIRE_VERSION));
    append_i32(input_blob, movement_substep_units);
    append_i32(input_blob, turn_snap_window_units);
    append_i32(input_blob, pass_absorb_window_units);
    append_i32(input_blob, bubble_overlap_center_mode);
    append_i32(input_blob, bubble_phase_init_mode);
    append_i32_array(input_blob, players);
    append_i32_array(input_blob, bubbles);
    append_i32_array(input_blob, phase_values);
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
    PackedInt32Array phase_values;
    PackedInt32Array blocked_grid;
    int32_t movement_substep_units = 0;
    int32_t turn_snap_window_units = DEFAULT_TURN_SNAP_WINDOW_UNITS;
    int32_t pass_absorb_window_units = DEFAULT_PASS_ABSORB_WINDOW_UNITS;
    int32_t bubble_overlap_center_mode = 0;
    int32_t bubble_phase_init_mode = 0;
    if (!decode_binary_input(
        input_blob,
        players,
        bubbles,
        phase_values,
        blocked_grid,
        movement_substep_units,
        turn_snap_window_units,
        pass_absorb_window_units,
        bubble_overlap_center_mode,
        bubble_phase_init_mode
    )) {
        return UtilityFunctions::var_to_bytes(result);
    }
    const int32_t player_stride = 16;
    if (players.size() <= 0 || (players.size() % player_stride) != 0) {
        return UtilityFunctions::var_to_bytes(result);
    }

    KernelContext ctx;
    ctx.movement_substep_units = movement_substep_units;
    ctx.turn_snap_window_units = turn_snap_window_units;
    ctx.pass_absorb_window_units = pass_absorb_window_units;
    ctx.bubble_overlap_center_mode = bubble_overlap_center_mode;
    ctx.bubble_phase_init_mode = bubble_phase_init_mode;
    if (ctx.movement_substep_units <= 0) {
        return UtilityFunctions::var_to_bytes(result);
    }

    if ((phase_values.size() % PHASE_FIELDS_PER_ENTRY) != 0) {
        return UtilityFunctions::var_to_bytes(result);
    }
    const int32_t phase_count_total = phase_values.size() / PHASE_FIELDS_PER_ENTRY;
    ctx.phase_table.reserve(static_cast<size_t>(phase_count_total));
    for (int32_t i = 0; i < phase_values.size(); i += PHASE_FIELDS_PER_ENTRY) {
        PhaseRecord phase;
        phase.player_id = phase_values[i];
        phase.phase_x = phase_values[i + 1];
        phase.sign_x = phase_values[i + 2];
        phase.phase_y = phase_values[i + 3];
        phase.sign_y = phase_values[i + 4];
        ctx.phase_table.push_back(phase);
    }

    if ((bubbles.size() % BUBBLE_RECORD_STRIDE) != 0 || (blocked_grid.size() % 5) != 0) {
        return UtilityFunctions::var_to_bytes(result);
    }

    for (int32_t index = 0; index < bubbles.size(); index += BUBBLE_RECORD_STRIDE) {
        BubbleRecord bubble;
        bubble.bubble_id = bubbles[index];
        bubble.alive = bubbles[index + 1];
        bubble.cell_x = bubbles[index + 2];
        bubble.cell_y = bubbles[index + 3];
        bubble.footprint_cells = std::max(1, bubbles[index + 4]);
        bubble.phase_count = bubbles[index + 5];
        bubble.phase_values_offset = bubbles[index + 6];
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
    Array bubble_phase_updates;
    const int32_t *values = players.ptr();
    for (int32_t i = 0; i < players.size(); i += player_stride) {
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
        player.move_remainder_units = values[i + 12];
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
            player.move_remainder_units = 0;
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

            int32_t units_to_consume = player.move_remainder_units + resolve_movement_units_per_tick(player.speed_level);
            player.move_remainder_units = 0;

            while (units_to_consume > 0) {
                const int32_t step_units = std::min(ctx.movement_substep_units, units_to_consume);
                const Vec2i foot_cell = get_foot_cell(player);
                const Vec2i target_cell{foot_cell.x + player.command_move_x, foot_cell.y + player.command_move_y};
                const Vec2i current_abs = get_abs_pos(player);
                const Vec2i tentative_abs{
                    current_abs.x + (player.command_move_x * step_units),
                    current_abs.y + (player.command_move_y * step_units)
                };
                const bool direct_target_blocked = is_transition_blocked_for_player_at_pos(
                    ctx,
                    player.player_id,
                    foot_cell.x,
                    foot_cell.y,
                    target_cell.x,
                    target_cell.y,
                    tentative_abs.x,
                    tentative_abs.y
                );
                const int32_t rail = get_player_rail_constraint(ctx, player.player_id, foot_cell.x, foot_cell.y);
                // 撞墙也要判轨道门控：rail 要求 perpendicular center 但不满足 → turn_only（玩家不动）。
                if (direct_target_blocked) {
                    if (turn_snap_would_fail(player, rail, player.command_move_x, player.command_move_y, ctx.turn_snap_window_units)) {
                        turn_only = true;
                        player.move_remainder_units = 0;
                        break;
                    }
                } else if (!try_apply_turn_snap(
                    player,
                    foot_cell,
                    rail,
                    player.command_move_x,
                    player.command_move_y,
                    ctx.turn_snap_window_units
                )) {
                    turn_only = true;
                    player.move_remainder_units = 0;
                    break;
                }

                const Dictionary move_result = try_move_along_axis(
                    ctx,
                    player.player_id,
                    player,
                    player.command_move_x,
                    player.command_move_y,
                    step_units,
                    ctx.movement_substep_units
                );
                const Vector2i resolved_abs_pos = move_result.get("abs_pos", Vector2i());
                write_player_abs_pos(player, resolved_abs_pos.x, resolved_abs_pos.y);
                units_to_consume -= step_units;
                if (static_cast<bool>(move_result.get("blocked", false))) {
                    blocked = true;
                    player.move_remainder_units = 0;
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

        // Phase advance：玩家移动后按当前位置对每个泡泡的 phase 单调降级。
        // 遍历 bubble_id 升序（与 GD 端 advancer 顺序一致，保证确定性）。
        const Vec2i player_abs = get_abs_pos(player);
        std::vector<int32_t> bubble_ids;
        bubble_ids.reserve(ctx.bubbles_by_id.size());
        for (const auto &entry : ctx.bubbles_by_id) {
            bubble_ids.push_back(entry.first);
        }
        std::sort(bubble_ids.begin(), bubble_ids.end());
        for (const int32_t bubble_id : bubble_ids) {
            const BubbleRecord &bubble = ctx.bubbles_by_id[bubble_id];
            if (bubble.alive == 0) {
                continue;
            }
            const Vec2i center = resolve_bubble_reference_center(ctx, bubble, player_abs);
            const int32_t d_x = player_abs.x - center.x;
            const int32_t d_y = player_abs.y - center.y;

            const PhaseRecord *existing = find_phase(ctx, bubble, player.player_id);
            PhaseRecord new_phase;
            bool is_new_entry = false;
            if (existing == nullptr) {
                if (ctx.bubble_phase_init_mode != 1) {
                    continue;
                }
                if (std::abs(d_x) >= CELL_UNITS || std::abs(d_y) >= CELL_UNITS) {
                    continue;
                }
                new_phase.player_id = player.player_id;
                is_new_entry = true;
            } else {
                new_phase = *existing;
            }

            // 单调推进。
            const int32_t abs_dx = std::abs(d_x);
            const int32_t abs_dy = std::abs(d_y);
            int32_t target_x = PHASE_A;
            if (abs_dx >= CELL_UNITS) target_x = PHASE_C;
            else if (abs_dx >= HALF_CELL_UNITS) target_x = PHASE_B;
            int32_t target_y = PHASE_A;
            if (abs_dy >= CELL_UNITS) target_y = PHASE_C;
            else if (abs_dy >= HALF_CELL_UNITS) target_y = PHASE_B;

            bool changed = is_new_entry;
            if (target_x > new_phase.phase_x) {
                if (new_phase.phase_x == PHASE_A) {
                    new_phase.sign_x = sign_of(d_x);
                }
                new_phase.phase_x = target_x;
                changed = true;
            }
            if (target_y > new_phase.phase_y) {
                if (new_phase.phase_y == PHASE_A) {
                    new_phase.sign_y = sign_of(d_y);
                }
                new_phase.phase_y = target_y;
                changed = true;
            }

            if (!changed) {
                continue;
            }

            Dictionary update;
            update["bubble_id"] = bubble_id;
            update["player_id"] = player.player_id;
            update["phase_x"] = new_phase.phase_x;
            update["sign_x"] = new_phase.sign_x;
            update["phase_y"] = new_phase.phase_y;
            update["sign_y"] = new_phase.sign_y;
            update["removed"] = false;
            bubble_phase_updates.append(update);
        }

        Dictionary player_update;
        player_update["player_id"] = player.player_id;
        player_update["cell_x"] = player.cell_x;
        player_update["cell_y"] = player.cell_y;
        player_update["offset_x"] = player.offset_x;
        player_update["offset_y"] = player.offset_y;
        player_update["facing"] = player.facing;
        player_update["move_state"] = player.move_state;
        player_update["move_remainder_units"] = player.move_remainder_units;
        player_update["last_non_zero_move_x"] = player.last_non_zero_move_x;
        player_update["last_non_zero_move_y"] = player.last_non_zero_move_y;
        updates.append(player_update);
    }

    result["player_updates"] = updates;
    result["blocked_events"] = blocked_events;
    result["cell_changes"] = cell_changes;
    result["bubble_phase_updates"] = bubble_phase_updates;
    result["version"] = WIRE_VERSION;
    return UtilityFunctions::var_to_bytes(result);
}
