#ifndef QQT_NATIVE_CHECKSUM_BUILDER_H
#define QQT_NATIVE_CHECKSUM_BUILDER_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>

using namespace godot;

class QQTNativeChecksumBuilder : public RefCounted {
    GDCLASS(QQTNativeChecksumBuilder, RefCounted);

protected:
    static void _bind_methods();

public:
    QQTNativeChecksumBuilder() = default;
    ~QQTNativeChecksumBuilder() = default;

    int64_t build_checksum(
        int64_t tick_id,
        const PackedInt32Array &players,
        const PackedInt32Array &bubbles,
        const PackedInt32Array &items,
        const PackedInt32Array &static_grid,
        const PackedInt32Array &mode,
        const PackedInt32Array &match,
        int64_t rng_state
    ) const;
};

#endif
