#include "native_packed_state_codec.h"

#include "common/native_battle_packed_schema.h"

#include <cstdint>
#include <cstring>

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

using namespace godot;

namespace {
constexpr const char *KERNEL_VERSION = "kernel_v1";
constexpr uint32_t SNAPSHOT_PAYLOAD_VERSION = static_cast<uint32_t>(qqt::packed_schema::SCHEMA_VERSION);
static_assert(qqt::packed_schema::PLAYER_STRIDE == 16, "battle packed schema player stride changed unexpectedly");
static_assert(qqt::packed_schema::BUBBLE_STRIDE == 12, "battle packed schema bubble stride changed unexpectedly");
static_assert(qqt::packed_schema::ITEM_STRIDE == 8, "battle packed schema item stride changed unexpectedly");
static_assert(qqt::packed_schema::GRID_STRIDE == 4, "battle packed schema grid stride changed unexpectedly");

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

int64_t get_i64(const Dictionary &source, const StringName &key, int64_t fallback = 0) {
    const Variant value = source.get(key, fallback);
    return static_cast<int64_t>(value);
}

void append_u32(PackedByteArray &buffer, uint32_t value) {
    buffer.append(static_cast<uint8_t>(value & 0xFF));
    buffer.append(static_cast<uint8_t>((value >> 8) & 0xFF));
    buffer.append(static_cast<uint8_t>((value >> 16) & 0xFF));
    buffer.append(static_cast<uint8_t>((value >> 24) & 0xFF));
}

void append_i64(PackedByteArray &buffer, int64_t value) {
    uint64_t bits = static_cast<uint64_t>(value);
    for (int32_t shift = 0; shift < 64; shift += 8) {
        buffer.append(static_cast<uint8_t>((bits >> shift) & 0xFF));
    }
}

bool read_u32(const PackedByteArray &buffer, int32_t &cursor, uint32_t &value) {
    if (cursor + 4 > buffer.size()) {
        return false;
    }
    const uint8_t *data = buffer.ptr();
    value = static_cast<uint32_t>(data[cursor])
        | (static_cast<uint32_t>(data[cursor + 1]) << 8)
        | (static_cast<uint32_t>(data[cursor + 2]) << 16)
        | (static_cast<uint32_t>(data[cursor + 3]) << 24);
    cursor += 4;
    return true;
}

bool read_i64(const PackedByteArray &buffer, int32_t &cursor, int64_t &value) {
    if (cursor + 8 > buffer.size()) {
        return false;
    }
    const uint8_t *data = buffer.ptr();
    uint64_t bits = 0;
    for (int32_t shift = 0; shift < 64; shift += 8) {
        bits |= static_cast<uint64_t>(data[cursor++]) << shift;
    }
    value = static_cast<int64_t>(bits);
    return true;
}

void append_segment(PackedByteArray &buffer, const Variant &value) {
    const PackedByteArray segment = UtilityFunctions::var_to_bytes(value);
    append_u32(buffer, static_cast<uint32_t>(segment.size()));
    for (int32_t index = 0; index < segment.size(); ++index) {
        buffer.append(segment[index]);
    }
}

void append_raw_segment(PackedByteArray &buffer, const PackedByteArray &segment) {
    append_u32(buffer, static_cast<uint32_t>(segment.size()));
    for (int32_t index = 0; index < segment.size(); ++index) {
        buffer.append(segment[index]);
    }
}

Variant read_segment(const PackedByteArray &buffer, int32_t &cursor) {
    uint32_t segment_size = 0;
    if (!read_u32(buffer, cursor, segment_size) || cursor + static_cast<int32_t>(segment_size) > buffer.size()) {
        return Variant();
    }
    PackedByteArray segment;
    segment.resize(static_cast<int32_t>(segment_size));
    for (uint32_t index = 0; index < segment_size; ++index) {
        segment.set(static_cast<int32_t>(index), buffer[cursor + static_cast<int32_t>(index)]);
    }
    cursor += static_cast<int32_t>(segment_size);
    return UtilityFunctions::bytes_to_var(segment);
}
} // namespace

void QQTNativePackedStateCodec::_bind_methods() {
    ClassDB::bind_method(D_METHOD("get_kernel_version"), &QQTNativePackedStateCodec::get_kernel_version);
    ClassDB::bind_method(D_METHOD("get_battle_packed_schema_version"), &QQTNativePackedStateCodec::get_battle_packed_schema_version);
    ClassDB::bind_method(D_METHOD("pack_players", "sim_world"), &QQTNativePackedStateCodec::pack_players);
    ClassDB::bind_method(D_METHOD("pack_bubbles", "sim_world"), &QQTNativePackedStateCodec::pack_bubbles);
    ClassDB::bind_method(D_METHOD("pack_items", "sim_world"), &QQTNativePackedStateCodec::pack_items);
    ClassDB::bind_method(D_METHOD("pack_grid_static", "sim_world"), &QQTNativePackedStateCodec::pack_grid_static);
    ClassDB::bind_method(D_METHOD("unpack_player_positions", "buffer"), &QQTNativePackedStateCodec::unpack_player_positions);
    ClassDB::bind_method(D_METHOD("unpack_explosion_hits", "buffer"), &QQTNativePackedStateCodec::unpack_explosion_hits);
    ClassDB::bind_method(D_METHOD("pack_snapshot_payload", "payload"), &QQTNativePackedStateCodec::pack_snapshot_payload);
    ClassDB::bind_method(
        D_METHOD(
            "pack_snapshot_segments",
            "tick_id",
            "rng_state",
            "checksum",
            "players_segment",
            "bubbles_segment",
            "items_segment",
            "walls_segment",
            "match_segment",
            "mode_segment"
        ),
        &QQTNativePackedStateCodec::pack_snapshot_segments
    );
    ClassDB::bind_method(D_METHOD("unpack_snapshot_payload", "payload_bytes"), &QQTNativePackedStateCodec::unpack_snapshot_payload);
}

String QQTNativePackedStateCodec::get_kernel_version() const {
    return String(KERNEL_VERSION);
}

int64_t QQTNativePackedStateCodec::get_battle_packed_schema_version() const {
    return qqt::packed_schema::SCHEMA_VERSION;
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
    PackedByteArray encoded;
    append_u32(encoded, SNAPSHOT_PAYLOAD_VERSION);
    append_i64(encoded, get_i64(payload, "tick_id", 0));
    append_i64(encoded, get_i64(payload, "rng_state", 0));
    append_i64(encoded, get_i64(payload, "checksum", 0));
    append_segment(encoded, payload.get("players", Array()));
    append_segment(encoded, payload.get("bubbles", Array()));
    append_segment(encoded, payload.get("items", Array()));
    append_segment(encoded, payload.get("walls", Array()));
    append_segment(encoded, payload.get("match_state", Dictionary()));
    append_segment(encoded, payload.get("mode_state", Dictionary()));
    append_segment(encoded, payload.get("battle_packed_state", Dictionary()));
    return encoded;
}

PackedByteArray QQTNativePackedStateCodec::pack_snapshot_segments(
    int64_t tick_id,
    int64_t rng_state,
    int64_t checksum,
    const PackedByteArray &players_segment,
    const PackedByteArray &bubbles_segment,
    const PackedByteArray &items_segment,
    const PackedByteArray &walls_segment,
    const PackedByteArray &match_segment,
    const PackedByteArray &mode_segment
) const {
    PackedByteArray encoded;
    append_u32(encoded, SNAPSHOT_PAYLOAD_VERSION);
    append_i64(encoded, tick_id);
    append_i64(encoded, rng_state);
    append_i64(encoded, checksum);
    append_raw_segment(encoded, players_segment);
    append_raw_segment(encoded, bubbles_segment);
    append_raw_segment(encoded, items_segment);
    append_raw_segment(encoded, walls_segment);
    append_raw_segment(encoded, match_segment);
    append_raw_segment(encoded, mode_segment);
    return encoded;
}

Dictionary QQTNativePackedStateCodec::unpack_snapshot_payload(const PackedByteArray &payload_bytes) const {
    Dictionary payload;
    if (payload_bytes.is_empty()) {
        return payload;
    }

    int32_t cursor = 0;
    uint32_t version = 0;
    int64_t tick_id = 0;
    int64_t rng_state = 0;
    int64_t checksum = 0;
    if (
        !read_u32(payload_bytes, cursor, version)
        || version != SNAPSHOT_PAYLOAD_VERSION
        || !read_i64(payload_bytes, cursor, tick_id)
        || !read_i64(payload_bytes, cursor, rng_state)
        || !read_i64(payload_bytes, cursor, checksum)
    ) {
        return payload;
    }

    payload["version"] = static_cast<int64_t>(version);
    payload["tick_id"] = tick_id;
    payload["rng_state"] = rng_state;
    payload["checksum"] = checksum;
    payload["players"] = get_array(read_segment(payload_bytes, cursor));
    payload["bubbles"] = get_array(read_segment(payload_bytes, cursor));
    payload["items"] = get_array(read_segment(payload_bytes, cursor));
    payload["walls"] = get_array(read_segment(payload_bytes, cursor));
    payload["match_state"] = get_dictionary(read_segment(payload_bytes, cursor));
    payload["mode_state"] = get_dictionary(read_segment(payload_bytes, cursor));
    if (cursor < payload_bytes.size()) {
        payload["battle_packed_state"] = get_dictionary(read_segment(payload_bytes, cursor));
    }
    return payload;
}
