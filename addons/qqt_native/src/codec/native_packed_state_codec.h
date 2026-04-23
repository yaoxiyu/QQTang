#ifndef QQT_NATIVE_PACKED_STATE_CODEC_H
#define QQT_NATIVE_PACKED_STATE_CODEC_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>

using namespace godot;

class QQTNativePackedStateCodec : public RefCounted {
    GDCLASS(QQTNativePackedStateCodec, RefCounted);

protected:
    static void _bind_methods();

public:
    QQTNativePackedStateCodec() = default;
    ~QQTNativePackedStateCodec() = default;

    PackedInt32Array pack_players(const Variant &sim_world) const;
    PackedInt32Array pack_bubbles(const Variant &sim_world) const;
    PackedInt32Array pack_items(const Variant &sim_world) const;
    PackedInt32Array pack_grid_static(const Variant &sim_world) const;
    Array unpack_player_positions(const PackedInt32Array &buffer) const;
    Array unpack_explosion_hits(const PackedInt32Array &buffer) const;
};

#endif
