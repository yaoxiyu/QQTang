#ifndef QQT_NATIVE_SNAPSHOT_RING_H
#define QQT_NATIVE_SNAPSHOT_RING_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>

#include <vector>

using namespace godot;

class QQTNativeSnapshotRing : public RefCounted {
    GDCLASS(QQTNativeSnapshotRing, RefCounted);

    struct SnapshotSlot {
        bool occupied = false;
        int64_t tick_id = -1;
        PackedByteArray bytes;
    };

    int32_t capacity_ = 0;
    std::vector<SnapshotSlot> slots_;

protected:
    static void _bind_methods();

public:
    QQTNativeSnapshotRing() = default;
    ~QQTNativeSnapshotRing() = default;

    void configure(int32_t capacity);
    void put_snapshot(int64_t tick_id, const PackedByteArray &snapshot_bytes);
    bool has_snapshot(int64_t tick_id) const;
    PackedByteArray get_snapshot(int64_t tick_id) const;
    void clear();
};

#endif
