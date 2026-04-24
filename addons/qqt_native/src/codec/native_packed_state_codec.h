#ifndef QQT_NATIVE_PACKED_STATE_CODEC_H
#define QQT_NATIVE_PACKED_STATE_CODEC_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/string.hpp>

using namespace godot;

class QQTNativePackedStateCodec : public RefCounted {
    GDCLASS(QQTNativePackedStateCodec, RefCounted);

protected:
    static void _bind_methods();

public:
    QQTNativePackedStateCodec() = default;
    ~QQTNativePackedStateCodec() = default;

    String get_kernel_version() const;
    int64_t get_battle_packed_schema_version() const;
    PackedInt32Array pack_players(const Variant &sim_world) const;
    PackedInt32Array pack_bubbles(const Variant &sim_world) const;
    PackedInt32Array pack_items(const Variant &sim_world) const;
    PackedInt32Array pack_grid_static(const Variant &sim_world) const;
    Array unpack_player_positions(const PackedInt32Array &buffer) const;
    Array unpack_explosion_hits(const PackedInt32Array &buffer) const;
    PackedByteArray pack_snapshot_payload(const Dictionary &payload) const;
    PackedByteArray pack_snapshot_segments(
        int64_t tick_id,
        int64_t rng_state,
        int64_t checksum,
        const PackedByteArray &players_segment,
        const PackedByteArray &bubbles_segment,
        const PackedByteArray &items_segment,
        const PackedByteArray &walls_segment,
        const PackedByteArray &match_segment,
        const PackedByteArray &mode_segment
    ) const;
    Dictionary unpack_snapshot_payload(const PackedByteArray &payload_bytes) const;
};

#endif
