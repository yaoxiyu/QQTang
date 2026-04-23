#include "native_movement_kernel.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

using namespace godot;

namespace {
Dictionary make_empty_result() {
    Dictionary result;
    result["player_updates"] = Array();
    result["blocked_events"] = Array();
    result["cell_changes"] = Array();
    result["bubble_ignore_removals"] = Array();
    return result;
}
} // namespace

void QQTNativeMovementKernel::_bind_methods() {
    ClassDB::bind_method(D_METHOD("step_players", "input_blob"), &QQTNativeMovementKernel::step_players);
}

PackedByteArray QQTNativeMovementKernel::step_players(const PackedByteArray &input_blob) const {
    Dictionary result = make_empty_result();
    if (input_blob.is_empty()) {
        return UtilityFunctions::var_to_bytes(result);
    }

    const Variant input_variant = UtilityFunctions::bytes_to_var(input_blob);
    if (input_variant.get_type() != Variant::DICTIONARY) {
        return UtilityFunctions::var_to_bytes(result);
    }

    const Dictionary payload = input_variant;
    const Variant player_variant = payload.get("player_records", PackedInt32Array());
    if (player_variant.get_type() != Variant::PACKED_INT32_ARRAY) {
        return UtilityFunctions::var_to_bytes(result);
    }
    const PackedInt32Array players = player_variant;
    const int32_t stride = 16;
    if (players.size() <= 0 || (players.size() % stride) != 0) {
        return UtilityFunctions::var_to_bytes(result);
    }

    Array updates;
    const int32_t *values = players.ptr();
    for (int32_t i = 0; i < players.size(); i += stride) {
        const int32_t player_id = values[i];
        const int32_t cell_x = values[i + 4];
        const int32_t cell_y = values[i + 5];
        const int32_t offset_x = values[i + 6];
        const int32_t offset_y = values[i + 7];
        const int32_t facing = values[i + 10];
        const int32_t move_state = values[i + 11];
        const int32_t move_phase_ticks = values[i + 12];
        const int32_t last_non_zero_move_x = values[i + 8];
        const int32_t last_non_zero_move_y = values[i + 9];

        Dictionary player_update;
        player_update["player_id"] = player_id;
        player_update["cell_x"] = cell_x;
        player_update["cell_y"] = cell_y;
        player_update["offset_x"] = offset_x;
        player_update["offset_y"] = offset_y;
        player_update["facing"] = facing;
        player_update["move_state"] = move_state;
        player_update["move_phase_ticks"] = move_phase_ticks;
        player_update["last_non_zero_move_x"] = last_non_zero_move_x;
        player_update["last_non_zero_move_y"] = last_non_zero_move_y;
        updates.append(player_update);
    }

    result["player_updates"] = updates;
    return UtilityFunctions::var_to_bytes(result);
}
