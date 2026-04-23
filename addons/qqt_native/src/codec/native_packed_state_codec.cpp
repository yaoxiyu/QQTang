#include "native_packed_state_codec.h"

#include <godot_cpp/core/class_db.hpp>

using namespace godot;

void QQTNativePackedStateCodec::_bind_methods() {
    ClassDB::bind_method(D_METHOD("pack_players", "sim_world"), &QQTNativePackedStateCodec::pack_players);
    ClassDB::bind_method(D_METHOD("pack_bubbles", "sim_world"), &QQTNativePackedStateCodec::pack_bubbles);
    ClassDB::bind_method(D_METHOD("pack_items", "sim_world"), &QQTNativePackedStateCodec::pack_items);
    ClassDB::bind_method(D_METHOD("pack_grid_static", "sim_world"), &QQTNativePackedStateCodec::pack_grid_static);
    ClassDB::bind_method(D_METHOD("unpack_player_positions", "buffer"), &QQTNativePackedStateCodec::unpack_player_positions);
    ClassDB::bind_method(D_METHOD("unpack_explosion_hits", "buffer"), &QQTNativePackedStateCodec::unpack_explosion_hits);
}

PackedInt32Array QQTNativePackedStateCodec::pack_players(const Variant &sim_world) const {
    return PackedInt32Array();
}

PackedInt32Array QQTNativePackedStateCodec::pack_bubbles(const Variant &sim_world) const {
    return PackedInt32Array();
}

PackedInt32Array QQTNativePackedStateCodec::pack_items(const Variant &sim_world) const {
    return PackedInt32Array();
}

PackedInt32Array QQTNativePackedStateCodec::pack_grid_static(const Variant &sim_world) const {
    return PackedInt32Array();
}

Array QQTNativePackedStateCodec::unpack_player_positions(const PackedInt32Array &buffer) const {
    return Array();
}

Array QQTNativePackedStateCodec::unpack_explosion_hits(const PackedInt32Array &buffer) const {
    return Array();
}
