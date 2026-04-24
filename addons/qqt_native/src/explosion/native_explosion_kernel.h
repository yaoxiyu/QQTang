#ifndef QQT_NATIVE_EXPLOSION_KERNEL_H
#define QQT_NATIVE_EXPLOSION_KERNEL_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/string.hpp>

using namespace godot;

class QQTNativeExplosionKernel : public RefCounted {
    GDCLASS(QQTNativeExplosionKernel, RefCounted);

protected:
    static void _bind_methods();

public:
    QQTNativeExplosionKernel() = default;
    ~QQTNativeExplosionKernel() = default;

    String get_kernel_version() const;
    PackedByteArray resolve_explosions(const PackedByteArray &input_blob) const;
};

#endif
