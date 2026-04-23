#include "native_packed_state_codec.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

using namespace godot;

namespace {
Dictionary get_dictionary(const Variant &value) {
    if (value.get_type() == Variant::DICTIONARY) {
        return value;
    }
    return Dictionary();
}

Array get_array(const Variant &value) {
    if (value.get_type() == Variant::ARRAY) {
        return value;
    }
    return Array();
}

int32_t get_int(const Dictionary &source, const StringName &key, int32_t fallback = 0) {
    const Variant value = source.get(key, fallback);
    return static_cast<int32_t>(static_cast<int64_t>(value));
}
} // namespace

void QQTNativePackedStateCodec::_bind_methods() {
    ClassDB::bind_method(D_METHOD("pack_players", "sim_world"), &QQTNativePackedStateCodec::pack_players);
    ClassDB::bind_method(D_METHOD("pack_bubbles", "sim_world"), &QQTNativePackedStateCodec::pack_bubbles);
    ClassDB::bind_method(D_METHOD("pack_items", "sim_world"), &QQTNativePackedStateCodec::pack_items);
    ClassDB::bind_method(D_METHOD("pack_grid_static", "sim_world"), &QQTNativePackedStateCodec::pack_grid_static);
    ClassDB::bind_method(D_METHOD("unpack_player_positions", "buffer"), &QQTNativePackedStateCodec::unpack_player_positions);
    ClassDB::bind_method(D_METHOD("unpack_explosion_hits", "buffer"), &QQTNativePackedStateCodec::unpack_explosion_hits);
    ClassDB::bind_method(D_METHOD("pack_snapshot_payload", "payload"), &QQTNativePackedStateCodec::pack_snapshot_payload);
    ClassDB::bind_method(D_METHOD("unpack_snapshot_payload", "payload_bytes"), &QQTNativePackedStateCodec::unpack_snapshot_payload);
}

PackedInt32Array QQTNativePackedStateCodec::pack_players(const Variant &sim_world) const {
    PackedInt32Array packed;
    const Dictionary payload = get_dictionary(sim_world);
    const Array players = get_array(payload.get("players", Array()));
    for (int32_t i = 0; i < players.size(); ++i) {
        const Dictionary player = get_dictionary(players[i]);
        if (player.is_empty()) {
            continue;
        }
        packed.append(get_int(player, "entity_id", -1));
        packed.append(get_int(player, "cell_x", 0));
        packed.append(get_int(player, "cell_y", 0));
        packed.append(get_int(player, "alive", 0));
    }
    return packed;
}

PackedInt32Array QQTNativePackedStateCodec::pack_bubbles(const Variant &sim_world) const {
    PackedInt32Array packed;
    const Dictionary payload = get_dictionary(sim_world);
    const Array bubbles = get_array(payload.get("bubbles", Array()));
    for (int32_t i = 0; i < bubbles.size(); ++i) {
        const Dictionary bubble = get_dictionary(bubbles[i]);
        if (bubble.is_empty()) {
            continue;
        }
        packed.append(get_int(bubble, "entity_id", -1));
        packed.append(get_int(bubble, "cell_x", 0));
        packed.append(get_int(bubble, "cell_y", 0));
        packed.append(get_int(bubble, "alive", 0));
        packed.append(get_int(bubble, "bubble_range", 0));
    }
    return packed;
}

PackedInt32Array QQTNativePackedStateCodec::pack_items(const Variant &sim_world) const {
    PackedInt32Array packed;
    const Dictionary payload = get_dictionary(sim_world);
    const Array items = get_array(payload.get("items", Array()));
    for (int32_t i = 0; i < items.size(); ++i) {
        const Dictionary item = get_dictionary(items[i]);
        if (item.is_empty()) {
            continue;
        }
        packed.append(get_int(item, "entity_id", -1));
        packed.append(get_int(item, "cell_x", 0));
        packed.append(get_int(item, "cell_y", 0));
        packed.append(get_int(item, "item_type", 0));
        packed.append(get_int(item, "alive", 0));
    }
    return packed;
}

PackedInt32Array QQTNativePackedStateCodec::pack_grid_static(const Variant &sim_world) const {
    PackedInt32Array packed;
    const Dictionary payload = get_dictionary(sim_world);
    const Array walls = get_array(payload.get("walls", Array()));
    for (int32_t i = 0; i < walls.size(); ++i) {
        const Dictionary wall = get_dictionary(walls[i]);
        if (wall.is_empty()) {
            continue;
        }
        packed.append(get_int(wall, "cell_x", 0));
        packed.append(get_int(wall, "cell_y", 0));
        packed.append(get_int(wall, "tile_type", 0));
        packed.append(get_int(wall, "tile_flags", 0));
        packed.append(get_int(wall, "theme_variant", 0));
    }
    return packed;
}

Array QQTNativePackedStateCodec::unpack_player_positions(const PackedInt32Array &buffer) const {
    Array unpacked;
    const int32_t stride = 4;
    if (buffer.size() <= 0 || (buffer.size() % stride) != 0) {
        return unpacked;
    }
    const int32_t *values = buffer.ptr();
    for (int32_t i = 0; i < buffer.size(); i += stride) {
        Dictionary row;
        row["entity_id"] = values[i];
        row["cell_x"] = values[i + 1];
        row["cell_y"] = values[i + 2];
        row["alive"] = values[i + 3] != 0;
        unpacked.append(row);
    }
    return unpacked;
}

Array QQTNativePackedStateCodec::unpack_explosion_hits(const PackedInt32Array &buffer) const {
    Array unpacked;
    const int32_t stride = 5;
    if (buffer.size() <= 0 || (buffer.size() % stride) != 0) {
        return unpacked;
    }
    const int32_t *values = buffer.ptr();
    for (int32_t i = 0; i < buffer.size(); i += stride) {
        Dictionary row;
        row["source_bubble_id"] = values[i];
        row["target_type"] = values[i + 1];
        row["target_entity_id"] = values[i + 2];
        row["target_cell_x"] = values[i + 3];
        row["target_cell_y"] = values[i + 4];
        unpacked.append(row);
    }
    return unpacked;
}

PackedByteArray QQTNativePackedStateCodec::pack_snapshot_payload(const Dictionary &payload) const {
    return UtilityFunctions::var_to_bytes(payload);
}

Dictionary QQTNativePackedStateCodec::unpack_snapshot_payload(const PackedByteArray &payload_bytes) const {
    const Variant decoded = UtilityFunctions::bytes_to_var(payload_bytes);
    return get_dictionary(decoded);
}
