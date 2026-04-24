#ifndef QQT_NATIVE_MOVEMENT_KERNEL_H
#define QQT_NATIVE_MOVEMENT_KERNEL_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/string.hpp>

using namespace godot;

class QQTNativeMovementKernel : public RefCounted {
    GDCLASS(QQTNativeMovementKernel, RefCounted);

protected:
    static void _bind_methods();

public:
    QQTNativeMovementKernel() = default;
    ~QQTNativeMovementKernel() = default;

    String get_kernel_version() const;
    PackedByteArray step_players(const PackedByteArray &input_blob) const;
    PackedByteArray step_players_packed(
        const PackedInt32Array &players,
        const PackedInt32Array &bubbles,
        const PackedInt32Array &ignore_values,
        const PackedInt32Array &blocked_grid,
        int32_t movement_step_units,
        int32_t turn_snap_window_units,
        int32_t pass_absorb_window_units
    ) const;
};

#endif
