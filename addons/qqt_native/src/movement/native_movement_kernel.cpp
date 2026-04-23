#include "native_movement_kernel.h"

#include <godot_cpp/core/class_db.hpp>

using namespace godot;

void QQTNativeMovementKernel::_bind_methods() {
    ClassDB::bind_method(D_METHOD("step_players", "input_blob"), &QQTNativeMovementKernel::step_players);
}

PackedByteArray QQTNativeMovementKernel::step_players(const PackedByteArray &input_blob) const {
    return PackedByteArray();
}
