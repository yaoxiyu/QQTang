#include "native_explosion_kernel.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

using namespace godot;

namespace {
Dictionary make_empty_result() {
    Dictionary result;
    result["covered_cells"] = Array();
    result["hit_entries"] = Array();
    result["destroy_cells"] = Array();
    result["chain_bubble_ids"] = Array();
    result["processed_bubble_ids"] = Array();
    return result;
}
} // namespace

void QQTNativeExplosionKernel::_bind_methods() {
    ClassDB::bind_method(D_METHOD("resolve_explosions", "input_blob"), &QQTNativeExplosionKernel::resolve_explosions);
}

PackedByteArray QQTNativeExplosionKernel::resolve_explosions(const PackedByteArray &input_blob) const {
    Dictionary result = make_empty_result();
    if (input_blob.is_empty()) {
        return UtilityFunctions::var_to_bytes(result);
    }

    const Variant input_variant = UtilityFunctions::bytes_to_var(input_blob);
    if (input_variant.get_type() != Variant::DICTIONARY) {
        return UtilityFunctions::var_to_bytes(result);
    }
    const Dictionary payload = input_variant;

    const Variant pending_variant = payload.get("pending_bubble_ids", PackedInt32Array());
    const Variant bubble_records_variant = payload.get("bubble_records", Array());
    if (pending_variant.get_type() != Variant::PACKED_INT32_ARRAY || bubble_records_variant.get_type() != Variant::ARRAY) {
        return UtilityFunctions::var_to_bytes(result);
    }

    const PackedInt32Array pending_bubble_ids = pending_variant;
    const Array bubble_records = bubble_records_variant;

    Dictionary bubbles_by_id;
    for (int32_t i = 0; i < bubble_records.size(); ++i) {
        const Variant &record_variant = bubble_records[i];
        if (record_variant.get_type() != Variant::DICTIONARY) {
            continue;
        }
        const Dictionary record = record_variant;
        const int32_t bubble_id = static_cast<int32_t>(static_cast<int64_t>(record.get("entity_id", -1)));
        if (bubble_id < 0) {
            continue;
        }
        bubbles_by_id[bubble_id] = record;
    }

    Array processed_bubble_ids;
    Array covered_cells;
    for (int32_t i = 0; i < pending_bubble_ids.size(); ++i) {
        const int32_t bubble_id = pending_bubble_ids[i];
        if (!bubbles_by_id.has(bubble_id)) {
            continue;
        }
        const Dictionary bubble = bubbles_by_id[bubble_id];
        const bool alive = static_cast<int64_t>(bubble.get("alive", 0)) != 0;
        if (!alive) {
            continue;
        }
        processed_bubble_ids.append(bubble_id);

        Dictionary covered;
        covered["bubble_id"] = bubble_id;
        covered["cell_x"] = static_cast<int32_t>(static_cast<int64_t>(bubble.get("cell_x", 0)));
        covered["cell_y"] = static_cast<int32_t>(static_cast<int64_t>(bubble.get("cell_y", 0)));
        covered_cells.append(covered);
    }

    result["processed_bubble_ids"] = processed_bubble_ids;
    result["covered_cells"] = covered_cells;
    return UtilityFunctions::var_to_bytes(result);
}
