#include "native_explosion_kernel.h"

#include <godot_cpp/core/class_db.hpp>

using namespace godot;

void QQTNativeExplosionKernel::_bind_methods() {
    ClassDB::bind_method(D_METHOD("resolve_explosions", "input_blob"), &QQTNativeExplosionKernel::resolve_explosions);
}

PackedByteArray QQTNativeExplosionKernel::resolve_explosions(const PackedByteArray &input_blob) const {
    return PackedByteArray();
}
