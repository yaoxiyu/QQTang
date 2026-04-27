#include "native_snapshot_ring.h"

#include <algorithm>
#include <cstring>

#include <godot_cpp/core/class_db.hpp>

using namespace godot;

namespace {
constexpr const char *KERNEL_VERSION = "kernel_v1";

inline int64_t normalize_slot_index(int64_t tick_id, int32_t capacity) {
    const int64_t capacity_i64 = static_cast<int64_t>(capacity);
    const int64_t raw = tick_id % capacity_i64;
    return raw < 0 ? raw + capacity_i64 : raw;
}
} // namespace

void QQTNativeSnapshotRing::_bind_methods() {
    ClassDB::bind_method(D_METHOD("get_kernel_version"), &QQTNativeSnapshotRing::get_kernel_version);
    ClassDB::bind_method(D_METHOD("configure", "capacity"), &QQTNativeSnapshotRing::configure);
    ClassDB::bind_method(D_METHOD("configure_with_limits", "capacity", "max_snapshot_bytes"), &QQTNativeSnapshotRing::configure_with_limits);
    ClassDB::bind_method(D_METHOD("put_snapshot", "tick_id", "snapshot_bytes"), &QQTNativeSnapshotRing::put_snapshot);
    ClassDB::bind_method(D_METHOD("has_snapshot", "tick_id"), &QQTNativeSnapshotRing::has_snapshot);
    ClassDB::bind_method(D_METHOD("get_snapshot", "tick_id"), &QQTNativeSnapshotRing::get_snapshot);
    ClassDB::bind_method(D_METHOD("get_metrics"), &QQTNativeSnapshotRing::get_metrics);
    ClassDB::bind_method(D_METHOD("clear"), &QQTNativeSnapshotRing::clear);
}

String QQTNativeSnapshotRing::get_kernel_version() const {
    return String(KERNEL_VERSION);
}

void QQTNativeSnapshotRing::configure(int32_t capacity) {
    if (capacity < 0) {
        capacity = 0;
    }
    capacity_ = capacity;
    max_snapshot_bytes_ = 0;
    reset_metrics();
    slots_.clear();
    slots_.resize(static_cast<size_t>(capacity_));
}

void QQTNativeSnapshotRing::configure_with_limits(int32_t capacity, int32_t max_snapshot_bytes) {
    configure(capacity);
    max_snapshot_bytes_ = std::max(0, max_snapshot_bytes);
}

void QQTNativeSnapshotRing::put_snapshot(int64_t tick_id, const PackedByteArray &snapshot_bytes) {
    put_count_++;
    if (capacity_ <= 0 || slots_.empty()) {
        return;
    }
    if (max_snapshot_bytes_ > 0 && snapshot_bytes.size() > max_snapshot_bytes_) {
        rejected_too_large_count_++;
        return;
    }
    const int64_t slot_index = normalize_slot_index(tick_id, capacity_);
    SnapshotSlot &slot = slots_[static_cast<size_t>(slot_index)];
    if (slot.occupied && slot.tick_id != tick_id) {
        overwrite_count_++;
    }
    if (slot.occupied) {
        current_bytes_stored_ -= slot.bytes.size();
    }
    slot.occupied = true;
    slot.tick_id = tick_id;
    write_slot_bytes(slot, snapshot_bytes);
    current_bytes_stored_ += slot.bytes.size();
    max_bytes_stored_ = std::max(max_bytes_stored_, current_bytes_stored_);
    total_bytes_written_ += snapshot_bytes.size();
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
    get_count_++;
    if (!has_snapshot(tick_id)) {
        miss_count_++;
        return PackedByteArray();
    }
    hit_count_++;
    const int64_t slot_index = normalize_slot_index(tick_id, capacity_);
    return slots_[static_cast<size_t>(slot_index)].bytes;
}

Dictionary QQTNativeSnapshotRing::get_metrics() const {
    Dictionary metrics;
    metrics["capacity"] = capacity_;
    metrics["max_snapshot_bytes"] = max_snapshot_bytes_;
    metrics["put_count"] = put_count_;
    metrics["get_count"] = get_count_;
    metrics["hit_count"] = hit_count_;
    metrics["miss_count"] = miss_count_;
    metrics["overwrite_count"] = overwrite_count_;
    metrics["rejected_too_large_count"] = rejected_too_large_count_;
    metrics["total_bytes_written"] = total_bytes_written_;
    metrics["current_bytes_stored"] = current_bytes_stored_;
    metrics["max_bytes_stored"] = max_bytes_stored_;
    return metrics;
}

void QQTNativeSnapshotRing::clear() {
    capacity_ = 0;
    max_snapshot_bytes_ = 0;
    reset_metrics();
    slots_.clear();
}

void QQTNativeSnapshotRing::reset_metrics() {
    put_count_ = 0;
    get_count_ = 0;
    hit_count_ = 0;
    miss_count_ = 0;
    overwrite_count_ = 0;
    rejected_too_large_count_ = 0;
    total_bytes_written_ = 0;
    current_bytes_stored_ = 0;
    max_bytes_stored_ = 0;
}

void QQTNativeSnapshotRing::write_slot_bytes(SnapshotSlot &slot, const PackedByteArray &snapshot_bytes) {
    const int32_t size = snapshot_bytes.size();
    slot.bytes.resize(size);
    if (size <= 0) {
        return;
    }
    std::memcpy(slot.bytes.ptrw(), snapshot_bytes.ptr(), static_cast<size_t>(size));
}
