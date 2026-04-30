#include "native_explosion_kernel.h"

#include <algorithm>
#include <cstdint>
#include <deque>
#include <string>
#include <unordered_map>
#include <unordered_set>
#include <vector>

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

using namespace godot;

namespace {
constexpr const char *KERNEL_VERSION = "native_kernel_v1";
constexpr int64_t WIRE_VERSION = 2;
constexpr int32_t EXPLOSION_PAYLOAD_MAGIC = 1163153745;

enum TargetType {
    TARGET_PLAYER = 0,
    TARGET_BUBBLE = 1,
    TARGET_ITEM = 2,
    TARGET_BREAKABLE_BLOCK = 3,
};

constexpr int32_t TILE_SOLID_WALL = 1;
constexpr int32_t TILE_BREAKABLE_BLOCK = 2;
constexpr int32_t BUBBLE_RECORD_STRIDE = 12;
constexpr int32_t PLAYER_RECORD_STRIDE = 6;
constexpr int32_t ITEM_RECORD_STRIDE = 5;
constexpr int32_t GRID_RECORD_STRIDE = 4;

struct BubbleRecord {
    int32_t entity_id = -1;
    bool alive = false;
    int32_t owner_player_id = -1;
    int32_t cell_x = 0;
    int32_t cell_y = 0;
    int32_t explode_tick = 0;
    int32_t bubble_range = 1;
    bool pierce = false;
    bool chain_triggered = false;
    int32_t bubble_type = 0;
    int32_t power = 1;
    int32_t footprint_cells = 1;
};

struct PlayerRecord {
    int32_t entity_id = -1;
    bool alive = false;
    int32_t life_state = 0;
    int32_t player_slot = 0;
    int32_t cell_x = 0;
    int32_t cell_y = 0;
};

struct ItemRecord {
    int32_t entity_id = -1;
    bool alive = false;
    int32_t item_type = 0;
    int32_t cell_x = 0;
    int32_t cell_y = 0;
};

struct GridRecord {
    int32_t cell_x = 0;
    int32_t cell_y = 0;
    int32_t tile_type = 0;
    int32_t tile_flags = 0;
};

Dictionary make_empty_result() {
    Dictionary result;
    result["version"] = WIRE_VERSION;
    result["covered_cells"] = Array();
    result["hit_entries"] = Array();
    result["destroy_cells"] = Array();
    result["chain_bubble_ids"] = Array();
    result["processed_bubble_ids"] = Array();
    return result;
}

PackedInt32Array get_packed_i32_array(const Variant &value) {
    if (value.get_type() == Variant::PACKED_INT32_ARRAY) {
        return value;
    }
    return PackedInt32Array();
}

int32_t get_int(const Dictionary &source, const StringName &key, int32_t fallback = 0) {
    return static_cast<int32_t>(static_cast<int64_t>(source.get(key, fallback)));
}

int64_t make_cell_key(int32_t x, int32_t y) {
    return (static_cast<int64_t>(x) << 32) ^ static_cast<uint32_t>(y);
}

int32_t positive_int(int32_t value, int32_t fallback = 1) {
    return value > 0 ? value : fallback;
}

int32_t footprint_size_for_cells(int32_t footprint_cells) {
    const int32_t cell_count = positive_int(footprint_cells);
    int32_t size = 1;
    while ((size * size) < cell_count) {
        ++size;
    }
    return size;
}

std::vector<int64_t> get_footprint_keys(const BubbleRecord &bubble) {
    std::vector<int64_t> keys;
    const int32_t cell_count = positive_int(bubble.footprint_cells);
    const int32_t size = footprint_size_for_cells(cell_count);
    keys.reserve(static_cast<size_t>(cell_count));
    for (int32_t y = 0; y < size; ++y) {
        for (int32_t x = 0; x < size; ++x) {
            if (static_cast<int32_t>(keys.size()) >= cell_count) {
                return keys;
            }
            keys.push_back(make_cell_key(bubble.cell_x + x, bubble.cell_y + y));
        }
    }
    return keys;
}

void index_bubble_footprint(std::unordered_map<int64_t, int32_t> &bubble_cell_lookup, const BubbleRecord &bubble) {
    for (const int64_t cell_key : get_footprint_keys(bubble)) {
        bubble_cell_lookup[cell_key] = bubble.entity_id;
    }
}

void erase_bubble_footprint(std::unordered_map<int64_t, int32_t> &bubble_cell_lookup, const BubbleRecord &bubble) {
    for (const int64_t cell_key : get_footprint_keys(bubble)) {
        const auto found = bubble_cell_lookup.find(cell_key);
        if (found != bubble_cell_lookup.end() && found->second == bubble.entity_id) {
            bubble_cell_lookup.erase(found);
        }
    }
}

std::string make_entity_hit_key(int32_t target_type, int32_t target_entity_id, int32_t target_cell_x, int32_t target_cell_y) {
    switch (target_type) {
        case TARGET_PLAYER:
            return "player:" + std::to_string(target_entity_id) + ":" + std::to_string(target_cell_x) + ":" + std::to_string(target_cell_y);
        case TARGET_BUBBLE:
            return "bubble:" + std::to_string(target_entity_id) + ":" + std::to_string(target_cell_x) + ":" + std::to_string(target_cell_y);
        case TARGET_ITEM:
            return "item:" + std::to_string(target_entity_id) + ":" + std::to_string(target_cell_x) + ":" + std::to_string(target_cell_y);
        case TARGET_BREAKABLE_BLOCK:
            return "block:" + std::to_string(target_cell_x) + ":" + std::to_string(target_cell_y);
        default:
            return "unknown";
    }
}

bool append_hit_entry(
    Array &hit_entries,
    std::unordered_set<std::string> &dedupe_keys,
    int32_t tick,
    const BubbleRecord &source_bubble,
    int32_t target_type,
    int32_t target_entity_id,
    int32_t target_cell_x,
    int32_t target_cell_y,
    const Dictionary &target_aux_data = Dictionary()
) {
    const std::string dedupe_key = make_entity_hit_key(target_type, target_entity_id, target_cell_x, target_cell_y);
    if (dedupe_keys.find(dedupe_key) != dedupe_keys.end()) {
        return false;
    }
    dedupe_keys.insert(dedupe_key);

    Dictionary hit_entry;
    hit_entry["tick"] = tick;
    hit_entry["source_bubble_id"] = source_bubble.entity_id;
    hit_entry["source_player_id"] = source_bubble.owner_player_id;
    hit_entry["source_cell_x"] = source_bubble.cell_x;
    hit_entry["source_cell_y"] = source_bubble.cell_y;
    hit_entry["target_type"] = target_type;
    hit_entry["target_entity_id"] = target_entity_id;
    hit_entry["target_cell_x"] = target_cell_x;
    hit_entry["target_cell_y"] = target_cell_y;
    hit_entry["target_aux_data"] = target_aux_data.duplicate(true);
    hit_entries.append(hit_entry);
    return true;
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
    int32_t &tick,
    PackedInt32Array &pending_bubble_ids,
    PackedInt32Array &bubble_records,
    PackedInt32Array &player_records,
    PackedInt32Array &item_records,
    PackedInt32Array &grid_records
) {
    int32_t cursor = 0;
    int32_t magic = 0;
    int32_t version = 0;
    if (!read_i32(input_blob, cursor, magic) || magic != EXPLOSION_PAYLOAD_MAGIC) {
        return false;
    }
    if (!read_i32(input_blob, cursor, version) || version != static_cast<int32_t>(WIRE_VERSION)) {
        return false;
    }
    if (
        !read_i32(input_blob, cursor, tick)
        || !read_i32_array(input_blob, cursor, pending_bubble_ids)
        || !read_i32_array(input_blob, cursor, bubble_records)
        || !read_i32_array(input_blob, cursor, player_records)
        || !read_i32_array(input_blob, cursor, item_records)
        || !read_i32_array(input_blob, cursor, grid_records)
    ) {
        return false;
    }
    return cursor == input_blob.size();
}
} // namespace

void QQTNativeExplosionKernel::_bind_methods() {
    ClassDB::bind_method(D_METHOD("get_kernel_version"), &QQTNativeExplosionKernel::get_kernel_version);
    ClassDB::bind_method(D_METHOD("resolve_explosions", "input_blob"), &QQTNativeExplosionKernel::resolve_explosions);
}

String QQTNativeExplosionKernel::get_kernel_version() const {
    return String(KERNEL_VERSION);
}

PackedByteArray QQTNativeExplosionKernel::resolve_explosions(const PackedByteArray &input_blob) const {
    Dictionary result = make_empty_result();
    if (input_blob.is_empty()) {
        return UtilityFunctions::var_to_bytes(result);
    }

    int32_t tick = 0;
    PackedInt32Array pending_bubble_ids;
    PackedInt32Array bubble_records;
    PackedInt32Array player_records;
    PackedInt32Array item_records;
    PackedInt32Array grid_records;
    if (!decode_binary_input(input_blob, tick, pending_bubble_ids, bubble_records, player_records, item_records, grid_records)) {
        const Variant input_variant = UtilityFunctions::bytes_to_var(input_blob);
        if (input_variant.get_type() != Variant::DICTIONARY) {
            return UtilityFunctions::var_to_bytes(result);
        }
        const Dictionary payload = input_variant;
        if (static_cast<int64_t>(payload.get("version", 0)) != WIRE_VERSION) {
            return UtilityFunctions::var_to_bytes(result);
        }

        const Variant pending_variant = payload.get("pending_bubble_ids", PackedInt32Array());
        bubble_records = get_packed_i32_array(payload.get("bubble_records", PackedInt32Array()));
        player_records = get_packed_i32_array(payload.get("player_records", PackedInt32Array()));
        item_records = get_packed_i32_array(payload.get("item_records", PackedInt32Array()));
        grid_records = get_packed_i32_array(payload.get("grid_records", PackedInt32Array()));
        if (pending_variant.get_type() != Variant::PACKED_INT32_ARRAY) {
            return UtilityFunctions::var_to_bytes(result);
        }
        pending_bubble_ids = pending_variant;
        tick = get_int(payload, "tick", 0);
    }
    if (
        (bubble_records.size() % BUBBLE_RECORD_STRIDE) != 0
        || (player_records.size() % PLAYER_RECORD_STRIDE) != 0
        || (item_records.size() % ITEM_RECORD_STRIDE) != 0
        || (grid_records.size() % GRID_RECORD_STRIDE) != 0
    ) {
        return UtilityFunctions::var_to_bytes(result);
    }

    std::unordered_map<int32_t, BubbleRecord> bubbles_by_id;
    std::unordered_map<int64_t, int32_t> bubble_cell_lookup;
    const int32_t *bubble_values = bubble_records.ptr();
    for (int32_t i = 0; i < bubble_records.size(); i += BUBBLE_RECORD_STRIDE) {
        BubbleRecord bubble;
        bubble.entity_id = bubble_values[i];
        bubble.alive = bubble_values[i + 1] != 0;
        bubble.owner_player_id = bubble_values[i + 2];
        bubble.cell_x = bubble_values[i + 3];
        bubble.cell_y = bubble_values[i + 4];
        bubble.explode_tick = bubble_values[i + 5];
        bubble.bubble_range = bubble_values[i + 6];
        bubble.pierce = bubble_values[i + 7] != 0;
        bubble.chain_triggered = bubble_values[i + 8] != 0;
        bubble.bubble_type = bubble_values[i + 9];
        bubble.power = positive_int(bubble_values[i + 10]);
        bubble.footprint_cells = positive_int(bubble_values[i + 11]);
        if (bubble.entity_id < 0) {
            continue;
        }
        bubbles_by_id[bubble.entity_id] = bubble;
        if (bubble.alive) {
            index_bubble_footprint(bubble_cell_lookup, bubble);
        }
    }

    std::unordered_map<int64_t, std::vector<PlayerRecord>> players_by_cell;
    const int32_t *player_values = player_records.ptr();
    for (int32_t i = 0; i < player_records.size(); i += PLAYER_RECORD_STRIDE) {
        PlayerRecord player;
        player.entity_id = player_values[i];
        player.alive = player_values[i + 1] != 0;
        player.life_state = player_values[i + 2];
        player.player_slot = player_values[i + 3];
        player.cell_x = player_values[i + 4];
        player.cell_y = player_values[i + 5];
        if (player.entity_id < 0 || !player.alive) {
            continue;
        }
        players_by_cell[make_cell_key(player.cell_x, player.cell_y)].push_back(player);
    }
    for (auto &entry : players_by_cell) {
        std::sort(entry.second.begin(), entry.second.end(), [](const PlayerRecord &left, const PlayerRecord &right) {
            return left.entity_id < right.entity_id;
        });
    }

    std::unordered_map<int64_t, ItemRecord> items_by_cell;
    const int32_t *item_values = item_records.ptr();
    for (int32_t i = 0; i < item_records.size(); i += ITEM_RECORD_STRIDE) {
        ItemRecord item;
        item.entity_id = item_values[i];
        item.alive = item_values[i + 1] != 0;
        item.item_type = item_values[i + 2];
        item.cell_x = item_values[i + 3];
        item.cell_y = item_values[i + 4];
        if (item.entity_id < 0 || !item.alive) {
            continue;
        }
        items_by_cell[make_cell_key(item.cell_x, item.cell_y)] = item;
    }

    std::unordered_map<int64_t, GridRecord> grid_by_cell;
    const int32_t *grid_values = grid_records.ptr();
    for (int32_t i = 0; i < grid_records.size(); i += GRID_RECORD_STRIDE) {
        GridRecord grid;
        grid.cell_x = grid_values[i];
        grid.cell_y = grid_values[i + 1];
        grid.tile_type = grid_values[i + 2];
        grid.tile_flags = grid_values[i + 3];
        grid_by_cell[make_cell_key(grid.cell_x, grid.cell_y)] = grid;
    }

    std::deque<int32_t> pending_queue;
    std::unordered_set<int32_t> queued_bubble_ids;
    std::unordered_set<int32_t> processed_bubble_ids_set;

    for (int32_t i = 0; i < pending_bubble_ids.size(); ++i) {
        const int32_t bubble_id = pending_bubble_ids[i];
        pending_queue.push_back(bubble_id);
        queued_bubble_ids.insert(bubble_id);
    }

    Array processed_bubble_ids;
    Array covered_cells;
    Array hit_entries;
    Array destroy_cells;
    Array chain_bubble_ids;
    std::unordered_set<std::string> hit_dedupe_keys;
    std::unordered_set<int64_t> destroy_cell_keys;

    const int32_t propagation_dirs[4][2] = {
        {0, -1},
        {0, 1},
        {-1, 0},
        {1, 0},
    };

    while (!pending_queue.empty()) {
        const int32_t bubble_id = pending_queue.front();
        pending_queue.pop_front();
        if (processed_bubble_ids_set.find(bubble_id) != processed_bubble_ids_set.end()) {
            continue;
        }
        const auto bubble_found = bubbles_by_id.find(bubble_id);
        if (bubble_found == bubbles_by_id.end() || !bubble_found->second.alive) {
            continue;
        }

        BubbleRecord &bubble = bubble_found->second;
        processed_bubble_ids_set.insert(bubble_id);
        processed_bubble_ids.append(bubble_id);

        auto collect_hits_at_cell = [&](int32_t cell_x, int32_t cell_y) {
            const int64_t cell_key = make_cell_key(cell_x, cell_y);
            const auto bubble_at_cell = bubble_cell_lookup.find(cell_key);
            if (bubble_at_cell != bubble_cell_lookup.end() && bubble_at_cell->second != bubble.entity_id) {
                const int32_t target_bubble_id = bubble_at_cell->second;
                const auto target_bubble_found = bubbles_by_id.find(target_bubble_id);
                if (target_bubble_found != bubbles_by_id.end() && target_bubble_found->second.alive) {
                    append_hit_entry(hit_entries, hit_dedupe_keys, tick, bubble, TARGET_BUBBLE, target_bubble_id, cell_x, cell_y);
                    if (processed_bubble_ids_set.find(target_bubble_id) == processed_bubble_ids_set.end()
                        && queued_bubble_ids.find(target_bubble_id) == queued_bubble_ids.end()) {
                        queued_bubble_ids.insert(target_bubble_id);
                        pending_queue.push_back(target_bubble_id);
                        chain_bubble_ids.append(target_bubble_id);
                    }
                }
            }

            const auto players_found = players_by_cell.find(cell_key);
            if (players_found != players_by_cell.end()) {
                for (const PlayerRecord &player : players_found->second) {
                    append_hit_entry(hit_entries, hit_dedupe_keys, tick, bubble, TARGET_PLAYER, player.entity_id, cell_x, cell_y);
                }
            }

            const auto item_found = items_by_cell.find(cell_key);
            if (item_found != items_by_cell.end() && item_found->second.alive) {
                append_hit_entry(hit_entries, hit_dedupe_keys, tick, bubble, TARGET_ITEM, item_found->second.entity_id, cell_x, cell_y);
            }
        };

        auto resolve_explosion_cell = [&](int32_t check_x, int32_t check_y) -> bool {
            const auto grid_found = grid_by_cell.find(make_cell_key(check_x, check_y));
            if (grid_found == grid_by_cell.end()) {
                return true;
            }

            const GridRecord &grid = grid_found->second;
            if (grid.tile_type == TILE_SOLID_WALL) {
                return true;
            }

            Dictionary covered;
            covered["bubble_id"] = bubble.entity_id;
            covered["cell_x"] = check_x;
            covered["cell_y"] = check_y;
            covered_cells.append(covered);

            if (grid.tile_type == TILE_BREAKABLE_BLOCK) {
                Dictionary block_aux_data;
                block_aux_data["profile_id"] = String("breakable_destroy_stop");
                block_aux_data["reaction"] = 0;
                append_hit_entry(
                    hit_entries,
                    hit_dedupe_keys,
                    tick,
                    bubble,
                    TARGET_BREAKABLE_BLOCK,
                    -1,
                    check_x,
                    check_y,
                    block_aux_data
                );
                const int64_t destroy_key = make_cell_key(check_x, check_y);
                if (destroy_cell_keys.find(destroy_key) == destroy_cell_keys.end()) {
                    destroy_cell_keys.insert(destroy_key);
                    Dictionary destroy_cell;
                    destroy_cell["cell_x"] = check_x;
                    destroy_cell["cell_y"] = check_y;
                    destroy_cells.append(destroy_cell);
                }
                return true;
            }

            collect_hits_at_cell(check_x, check_y);
            return false;
        };

        if (bubble.bubble_type == 2) {
            const int32_t size = bubble.power <= 1 ? 3 : 6;
            const int32_t footprint_size = footprint_size_for_cells(bubble.footprint_cells);
            const int32_t margin = (size - footprint_size) / 2;
            const int32_t start_x = bubble.cell_x - margin;
            const int32_t start_y = bubble.cell_y - margin;
            for (int32_t y = 0; y < size; ++y) {
                for (int32_t x = 0; x < size; ++x) {
                    resolve_explosion_cell(start_x + x, start_y + y);
                }
            }
        } else {
            resolve_explosion_cell(bubble.cell_x, bubble.cell_y);

            const int32_t bubble_range = positive_int(bubble.power);
            for (int32_t dir_index = 0; dir_index < 4; ++dir_index) {
                const int32_t dir_x = propagation_dirs[dir_index][0];
                const int32_t dir_y = propagation_dirs[dir_index][1];
                for (int32_t step = 1; step <= bubble_range; ++step) {
                    const int32_t check_x = bubble.cell_x + (dir_x * step);
                    const int32_t check_y = bubble.cell_y + (dir_y * step);
                    if (resolve_explosion_cell(check_x, check_y)) {
                        break;
                    }
                }
            }
        }

        bubble.alive = false;
        erase_bubble_footprint(bubble_cell_lookup, bubble);
    }

    result["processed_bubble_ids"] = processed_bubble_ids;
    result["covered_cells"] = covered_cells;
    result["hit_entries"] = hit_entries;
    result["destroy_cells"] = destroy_cells;
    result["chain_bubble_ids"] = chain_bubble_ids;
    result["version"] = WIRE_VERSION;
    return UtilityFunctions::var_to_bytes(result);
}

