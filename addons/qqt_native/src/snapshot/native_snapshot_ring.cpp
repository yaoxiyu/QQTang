#include "native_snapshot_ring.h"

#include <algorithm>

#include <godot_cpp/core/class_db.hpp>

using namespace godot;

namespace {
inline int64_t normalize_slot_index(int64_t tick_id, int32_t capacity) {
    const int64_t capacity_i64 = static_cast<int64_t>(capacity);
    const int64_t raw = tick_id % capacity_i64;
    return raw < 0 ? raw + capacity_i64 : raw;
}
} // namespace

void QQTNativeSnapshotRing::_bind_methods() {
    ClassDB::bind_method(D_METHOD("configure", "capacity"), &QQTNativeSnapshotRing::configure);
    ClassDB::bind_method(D_METHOD("put_snapshot", "tick_id", "snapshot_bytes"), &QQTNativeSnapshotRing::put_snapshot);
    ClassDB::bind_method(D_METHOD("has_snapshot", "tick_id"), &QQTNativeSnapshotRing::has_snapshot);
    ClassDB::bind_method(D_METHOD("get_snapshot", "tick_id"), &QQTNativeSnapshotRing::get_snapshot);
    ClassDB::bind_method(D_METHOD("clear"), &QQTNativeSnapshotRing::clear);
}

void QQTNativeSnapshotRing::configure(int32_t capacity) {
    if (capacity < 0) {
        capacity = 0;
    }
    capacity_ = capacity;
    slots_.clear();
    slots_.resize(static_cast<size_t>(capacity_));
}

void QQTNativeSnapshotRing::put_snapshot(int64_t tick_id, const PackedByteArray &snapshot_bytes) {
    if (capacity_ <= 0 || slots_.empty()) {
        return;
    }
    const int64_t slot_index = normalize_slot_index(tick_id, capacity_);
    SnapshotSlot &slot = slots_[static_cast<size_t>(slot_index)];
    slot.occupied = true;
    slot.tick_id = tick_id;
    slot.bytes = snapshot_bytes;
}

bool QQTNativeSnapshotRing::has_snapshot(int64_t tick_id) const {
    if (capacity_ <= 0 || slots_.empty()) {
        return false;
    }
    const int64_t slot_index = normalize_slot_index(tick_id, capacity_);
    const SnapshotSlot &slot = slots_[static_cast<size_t>(slot_index)];
    return slot.occupied && slot.tick_id == tick_id;
}

PackedByteArray QQTNativeSnapshotRing::get_snapshot(int64_t tick_id) const {
    if (!has_snapshot(tick_id)) {
        return PackedByteArray();
    }
    const int64_t slot_index = normalize_slot_index(tick_id, capacity_);
    return slots_[static_cast<size_t>(slot_index)].bytes;
}

void QQTNativeSnapshotRing::clear() {
    capacity_ = 0;
    slots_.clear();
}
