#ifndef QQT_NATIVE_SNAPSHOT_RING_H
#define QQT_NATIVE_SNAPSHOT_RING_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/string.hpp>

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
    int32_t max_snapshot_bytes_ = 0;
    int64_t put_count_ = 0;
    mutable int64_t get_count_ = 0;
    mutable int64_t hit_count_ = 0;
    mutable int64_t miss_count_ = 0;
    int64_t overwrite_count_ = 0;
    int64_t rejected_too_large_count_ = 0;
    int64_t total_bytes_written_ = 0;
    int64_t current_bytes_stored_ = 0;
    int64_t max_bytes_stored_ = 0;
    std::vector<SnapshotSlot> slots_;

    void reset_metrics();
    void write_slot_bytes(SnapshotSlot &slot, const PackedByteArray &snapshot_bytes);

protected:
    static void _bind_methods();

public:
    QQTNativeSnapshotRing() = default;
    ~QQTNativeSnapshotRing() = default;

    String get_kernel_version() const;
    void configure(int32_t capacity);
    void configure_with_limits(int32_t capacity, int32_t max_snapshot_bytes);
    void put_snapshot(int64_t tick_id, const PackedByteArray &snapshot_bytes);
    bool has_snapshot(int64_t tick_id) const;
    PackedByteArray get_snapshot(int64_t tick_id) const;
    Dictionary get_metrics() const;
    void clear();
};

#endif
