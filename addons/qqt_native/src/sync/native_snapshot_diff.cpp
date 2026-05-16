#include "sync/native_snapshot_diff.h"

#include "sync/sync_kernel_version.h"

#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/variant.hpp>

namespace {
constexpr int32_t REASON_MISSING = 1;
constexpr int32_t REASON_LOCAL_PLAYER = 2;
constexpr int32_t REASON_BUBBLES = 4;
constexpr int32_t REASON_ITEMS = 8;
constexpr int32_t REASON_RNG = 16;
constexpr int32_t REASON_WALLS = 32;

bool variant_equal(const Variant &left, const Variant &right);

bool array_equal(const Array &left, const Array &right) {
    if (left.size() != right.size()) {
        return false;
    }
    for (int64_t i = 0; i < left.size(); ++i) {
        if (!variant_equal(left[i], right[i])) {
            return false;
        }
    }
    return true;
}

bool dictionary_equal(const Dictionary &left, const Dictionary &right) {
    if (left.size() != right.size()) {
        return false;
    }
    Array keys = left.keys();
    for (int64_t i = 0; i < keys.size(); ++i) {
        Variant key = keys[i];
        if (!right.has(key)) {
            return false;
        }
        if (!variant_equal(left[key], right[key])) {
            return false;
        }
    }
    return true;
}

bool variant_equal(const Variant &left, const Variant &right) {
    if (left.get_type() == Variant::DICTIONARY && right.get_type() == Variant::DICTIONARY) {
        return dictionary_equal(Dictionary(left), Dictionary(right));
    }
    if (left.get_type() == Variant::ARRAY && right.get_type() == Variant::ARRAY) {
        return array_equal(Array(left), Array(right));
    }
    if ((left.get_type() == Variant::FLOAT || left.get_type() == Variant::INT) &&
        (right.get_type() == Variant::FLOAT || right.get_type() == Variant::INT)) {
        return double(left) == double(right);
    }
    return left == right;
}

Dictionary find_local_player(const Array &players, int32_t local_peer_id) {
    for (int64_t i = 0; i < players.size(); ++i) {
        Variant raw = players[i];
        if (raw.get_type() != Variant::DICTIONARY) {
            continue;
        }
        Dictionary player = raw;
        if (int32_t(int64_t(player.get("player_slot", -1))) == local_peer_id) {
            return player;
        }
    }
    return Dictionary();
}

bool ignored_has(const Array &ignored_keys, const String &key_name) {
    for (int64_t i = 0; i < ignored_keys.size(); ++i) {
        if (String(ignored_keys[i]) == key_name) {
            return true;
        }
    }
    return false;
}

bool dictionary_equal_ignoring(const Dictionary &left, const Dictionary &right, const Array &ignored_keys) {
    Array left_keys = left.keys();
    for (int64_t i = 0; i < left_keys.size(); ++i) {
        Variant key = left_keys[i];
        if (ignored_has(ignored_keys, String(key))) {
            continue;
        }
        if (!right.has(key) || !variant_equal(left[key], right[key])) {
            return false;
        }
    }
    Array right_keys = right.keys();
    for (int64_t i = 0; i < right_keys.size(); ++i) {
        Variant key = right_keys[i];
        if (ignored_has(ignored_keys, String(key))) {
            continue;
        }
        if (!left.has(key)) {
            return false;
        }
    }
    return true;
}

Dictionary make_result(bool equal, int32_t reason_mask, const String &section) {
    Dictionary result;
    result["equal"] = equal;
    result["reason_mask"] = reason_mask;
    result["first_diff_section"] = section;
    result["first_diff_index"] = -1;
    result["first_diff_field"] = "";
    result["local_value"] = Variant();
    result["authority_value"] = Variant();
    result["force_resync_reason_mask"] = 0;
    return result;
}
} // namespace

void QQTNativeSnapshotDiff::_bind_methods() {
    ClassDB::bind_method(D_METHOD("get_kernel_version"), &QQTNativeSnapshotDiff::get_kernel_version);
    ClassDB::bind_method(D_METHOD("diff_snapshots", "local_snapshot", "authority_snapshot", "options"), &QQTNativeSnapshotDiff::diff_snapshots);
    ClassDB::bind_method(D_METHOD("diff_packed_state", "local_packed", "authority_packed", "options"), &QQTNativeSnapshotDiff::diff_packed_state);
}

String QQTNativeSnapshotDiff::get_kernel_version() const {
    return qqt::sync::SYNC_KERNEL_VERSION;
}

Dictionary QQTNativeSnapshotDiff::diff_snapshots(const Dictionary &local_snapshot, const Dictionary &authority_snapshot, const Dictionary &options) const {
    if (local_snapshot.is_empty() || authority_snapshot.is_empty()) {
        return make_result(false, REASON_MISSING, "missing");
    }
    const int32_t local_peer_id = int32_t(int64_t(options.get("local_peer_id", -1)));
    const bool compare_bubbles = bool(options.get("compare_bubbles", true));
    const bool compare_items = bool(options.get("compare_items", true));
    const Array ignored_keys = options.get("ignored_local_player_keys", Array());
    const Array local_players = local_snapshot.get("players", Array());
    const Array authority_players = authority_snapshot.get("players", Array());
    bool players_equal = false;
    if (local_peer_id < 0) {
        players_equal = array_equal(local_players, authority_players);
    } else {
        Dictionary local_player = find_local_player(local_players, local_peer_id);
        Dictionary authority_player = find_local_player(authority_players, local_peer_id);
        players_equal = !local_player.is_empty() && !authority_player.is_empty() && dictionary_equal_ignoring(local_player, authority_player, ignored_keys);
    }
    if (!players_equal) {
        return make_result(false, REASON_LOCAL_PLAYER, "local_player");
    }
    if (compare_bubbles && !array_equal(local_snapshot.get("bubbles", Array()), authority_snapshot.get("bubbles", Array()))) {
        return make_result(false, REASON_BUBBLES, "bubbles");
    }
    if (compare_items && !array_equal(local_snapshot.get("items", Array()), authority_snapshot.get("items", Array()))) {
        return make_result(false, REASON_ITEMS, "items");
    }
    if (!array_equal(local_snapshot.get("walls", Array()), authority_snapshot.get("walls", Array()))) {
        return make_result(false, REASON_WALLS, "walls");
    }
    const int64_t local_rng = int64_t(local_snapshot.get("rng_state", 0));
    const int64_t authority_rng = int64_t(authority_snapshot.get("rng_state", 0));
    if (local_rng != 0 && authority_rng != 0 && local_rng != authority_rng) {
        return make_result(false, REASON_RNG, "rng_state");
    }
    return make_result(true, 0, "");
}

Dictionary QQTNativeSnapshotDiff::diff_packed_state(const Dictionary &local_packed, const Dictionary &authority_packed, const Dictionary &options) const {
    return diff_snapshots(local_packed, authority_packed, options);
}
