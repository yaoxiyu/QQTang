#ifndef QQT_NATIVE_MOVEMENT_KERNEL_H
#define QQT_NATIVE_MOVEMENT_KERNEL_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>

using namespace godot;

class QQTNativeMovementKernel : public RefCounted {
    GDCLASS(QQTNativeMovementKernel, RefCounted);

protected:
    static void _bind_methods();

public:
    QQTNativeMovementKernel() = default;
    ~QQTNativeMovementKernel() = default;

    PackedByteArray step_players(const PackedByteArray &input_blob) const;
};

#endif
