#include "native_checksum_builder.h"

#include <cstdint>

#include <godot_cpp/core/class_db.hpp>

using namespace godot;

namespace {
constexpr uint64_t FNV_OFFSET_BASIS = 1469598103934665603ULL;
constexpr uint64_t FNV_PRIME = 1099511628211ULL;

inline void fnv_mix(uint64_t &hash_accumulator, int64_t value) {
    hash_accumulator = (hash_accumulator ^ static_cast<uint64_t>(value)) * FNV_PRIME;
}

inline void hash_array(uint64_t &hash_accumulator, const PackedInt32Array &values) {
    const int32_t *data = values.ptr();
    const int32_t count = values.size();
    for (int32_t i = 0; i < count; ++i) {
        fnv_mix(hash_accumulator, static_cast<int64_t>(data[i]));
    }
}
} // namespace

void QQTNativeChecksumBuilder::_bind_methods() {
    ClassDB::bind_method(
        D_METHOD(
            "build_checksum",
            "tick_id",
            "players",
            "bubbles",
            "items",
            "static_grid",
            "mode",
            "match",
            "rng_state"
        ),
        &QQTNativeChecksumBuilder::build_checksum
    );
}

int64_t QQTNativeChecksumBuilder::build_checksum(
    int64_t tick_id,
    const PackedInt32Array &players,
    const PackedInt32Array &bubbles,
    const PackedInt32Array &items,
    const PackedInt32Array &static_grid,
    const PackedInt32Array &mode,
    const PackedInt32Array &match,
    int64_t rng_state
) const {
    uint64_t hash_value_u64 = FNV_OFFSET_BASIS;

    fnv_mix(hash_value_u64, tick_id);
    fnv_mix(hash_value_u64, rng_state);

    // Contract: packed inputs must already be normalized to the canonical
    // GDScript ordering before reaching native. This keeps the native side
    // deterministic without depending on object graphs or unstable iteration.
    hash_array(hash_value_u64, match);
    hash_array(hash_value_u64, players);
    hash_array(hash_value_u64, bubbles);
    hash_array(hash_value_u64, items);
    hash_array(hash_value_u64, static_grid);
    hash_array(hash_value_u64, mode);

    return static_cast<int64_t>(hash_value_u64);
}
