#include "sync/native_input_buffer.h"

#include "sync/sync_kernel_version.h"

#include <algorithm>
#include <godot_cpp/core/class_db.hpp>

void QQTNativeInputBuffer::_bind_methods() {
    ClassDB::bind_method(D_METHOD("get_kernel_version"), &QQTNativeInputBuffer::get_kernel_version);
    ClassDB::bind_method(D_METHOD("configure", "peer_capacity", "tick_capacity", "max_late_ticks"), &QQTNativeInputBuffer::configure);
    ClassDB::bind_method(D_METHOD("register_peer", "peer_id", "player_slot"), &QQTNativeInputBuffer::register_peer);
    ClassDB::bind_method(D_METHOD("push_input", "frame", "authority_tick"), &QQTNativeInputBuffer::push_input);
    ClassDB::bind_method(D_METHOD("collect_inputs_for_tick", "peer_ids", "tick_id"), &QQTNativeInputBuffer::collect_inputs_for_tick);
    ClassDB::bind_method(D_METHOD("ack_peer", "peer_id", "ack_tick"), &QQTNativeInputBuffer::ack_peer);
    ClassDB::bind_method(D_METHOD("get_metrics"), &QQTNativeInputBuffer::get_metrics);
    ClassDB::bind_method(D_METHOD("clear"), &QQTNativeInputBuffer::clear);
}

String QQTNativeInputBuffer::get_kernel_version() const {
    return qqt::sync::SYNC_KERNEL_VERSION;
}

void QQTNativeInputBuffer::configure(int32_t p_peer_capacity, int32_t p_tick_capacity, int32_t p_max_late_ticks) {
    peer_capacity = std::max(1, p_peer_capacity);
    tick_capacity = std::max(1, p_tick_capacity);
    max_late_ticks = std::max(0, p_max_late_ticks);
}

void QQTNativeInputBuffer::register_peer(int32_t peer_id, int32_t player_slot) {
    if (peer_id <= 0 && peer_slots.size() >= size_t(peer_capacity)) {
        return;
    }
    peer_slots[peer_id] = player_slot;
}

uint32_t QQTNativeInputBuffer::input_payload_hash(const Dictionary &frame) const {
    uint32_t h = 2166136261u;
    auto mix = [&](int32_t v) {
        h ^= uint32_t(v + 0x9e3779b9);
        h *= 16777619u;
    };
    mix(int32_t(int64_t(frame.get("move_x", 0))));
    mix(int32_t(int64_t(frame.get("move_y", 0))));
    mix(int32_t(int64_t(frame.get("action_bits", 0))));
    return h;
}

Dictionary QQTNativeInputBuffer::push_input(const Dictionary &frame, int32_t authority_tick) {
    Dictionary result;
    result["retargeted"] = false;
    if (frame.is_empty()) {
        result["status"] = "drop_empty";
        return result;
    }
    Dictionary sanitized = sanitize_frame(frame);
    const int32_t peer_id = int32_t(int64_t(sanitized.get("peer_id", 0)));
    const int32_t tick_id = int32_t(int64_t(sanitized.get("tick_id", 0)));
    const int32_t seq = int32_t(int64_t(sanitized.get("seq", tick_id)));

    if (peer_id <= 0) {
        invalid_peer_drop_count += 1;
        result["status"] = "drop_invalid_peer";
        return result;
    }

    if (authority_tick >= 0 && tick_id < authority_tick - max_late_ticks) {
        too_late_drop_count += 1;
        result["status"] = "drop_too_late";
        result["tick_id"] = tick_id;
        result["seq"] = seq;
        return result;
    }

    if (authority_tick >= 0 && tick_id <= authority_tick) {
        too_late_drop_count += 1;
        result["status"] = "drop_too_late";
        result["tick_id"] = tick_id;
        result["seq"] = seq;
        return result;
    }

    QQTInputIdentity identity{peer_id, tick_id, seq};
    uint32_t payload_hash = input_payload_hash(sanitized);
    auto id_it = accepted_payload_hash_by_identity.find(identity);
    if (id_it != accepted_payload_hash_by_identity.end()) {
        if (id_it->second == payload_hash) {
            duplicate_ignored_count += 1;
            result["status"] = "duplicate_ignored";
        } else {
            duplicate_conflict_count += 1;
            result["status"] = "duplicate_conflict";
        }
        result["peer_id"] = peer_id;
        result["tick_id"] = tick_id;
        result["seq"] = seq;
        return result;
    }

    int32_t latest_seq = -1;
    auto peer_tick_it = latest_seq_by_peer_tick.find(peer_id);
    if (peer_tick_it != latest_seq_by_peer_tick.end()) {
        auto tick_seq_it = peer_tick_it->second.find(tick_id);
        if (tick_seq_it != peer_tick_it->second.end()) {
            latest_seq = tick_seq_it->second;
        }
    }

    if (seq < latest_seq) {
        stale_seq_drop_count += 1;
        result["status"] = "drop_stale_seq";
        result["peer_id"] = peer_id;
        result["tick_id"] = tick_id;
        result["seq"] = seq;
        return result;
    }

    std::map<int32_t, Dictionary> &peer_frames = frames_by_peer[peer_id];
    auto existing_it = peer_frames.find(tick_id);

    if (existing_it != peer_frames.end() && seq > latest_seq) {
        peer_frames[tick_id] = sanitized;
        latest_seq_by_peer_tick[peer_id][tick_id] = seq;
        accepted_payload_hash_by_identity[identity] = payload_hash;
        last_input_by_peer[peer_id] = sanitized;
        replaced_by_higher_seq_count += 1;
        result["status"] = "replaced_by_higher_seq";
    } else if (existing_it == peer_frames.end()) {
        peer_frames[tick_id] = sanitized;
        latest_seq_by_peer_tick[peer_id][tick_id] = seq;
        accepted_payload_hash_by_identity[identity] = payload_hash;
        last_input_by_peer[peer_id] = sanitized;
        accepted_count += 1;
        result["status"] = "accepted";
    }

    last_seq_by_peer[peer_id] = std::max(last_seq_by_peer[peer_id], seq);
    evict_old_ticks(peer_id, tick_id);
    result["peer_id"] = peer_id;
    result["tick_id"] = tick_id;
    result["seq"] = seq;
    return result;
}

Array QQTNativeInputBuffer::collect_inputs_for_tick(const Array &peer_ids, int32_t tick_id) {
    Array result;
    for (int64_t index = 0; index < peer_ids.size(); ++index) {
        const int32_t peer_id = int32_t(int64_t(peer_ids[index]));
        const auto peer_it = frames_by_peer.find(peer_id);
        if (peer_it != frames_by_peer.end()) {
            const auto frame_it = peer_it->second.find(tick_id);
            if (frame_it != peer_it->second.end()) {
                result.append(frame_it->second.duplicate(true));
                continue;
            }
        }
        result.append(fallback_input(peer_id, tick_id));
    }
    return result;
}

void QQTNativeInputBuffer::ack_peer(int32_t peer_id, int32_t ack_tick) {
    auto ack_it = last_ack_tick_by_peer.find(peer_id);
    if (ack_it != last_ack_tick_by_peer.end() && ack_tick <= ack_it->second) {
        stale_ack_count += 1;
        return;
    }
    last_ack_tick_by_peer[peer_id] = ack_tick;
    auto peer_it = frames_by_peer.find(peer_id);
    if (peer_it == frames_by_peer.end()) {
        return;
    }
    for (auto it = peer_it->second.begin(); it != peer_it->second.end();) {
        if (it->first <= ack_tick) {
            const int32_t evicted_tick = it->first;
            latest_seq_by_peer_tick[peer_id].erase(evicted_tick);
            for (auto id_it = accepted_payload_hash_by_identity.begin(); id_it != accepted_payload_hash_by_identity.end();) {
                if (id_it->first.peer_id == peer_id && id_it->first.tick_id <= ack_tick) {
                    id_it = accepted_payload_hash_by_identity.erase(id_it);
                } else {
                    ++id_it;
                }
            }
            it = peer_it->second.erase(it);
            ack_evicted_count += 1;
        } else {
            ++it;
        }
    }
}

Dictionary QQTNativeInputBuffer::get_metrics() const {
    Dictionary metrics;
    metrics["accepted_count"] = accepted_count;
    metrics["merged_count"] = 0;
    metrics["stale_seq_drop_count"] = stale_seq_drop_count;
    metrics["too_late_drop_count"] = too_late_drop_count;
    metrics["late_retarget_count"] = 0;
    metrics["ack_evicted_count"] = ack_evicted_count;
    metrics["fallback_idle_count"] = fallback_idle_count;
    metrics["duplicate_ignored_count"] = duplicate_ignored_count;
    metrics["duplicate_conflict_count"] = duplicate_conflict_count;
    metrics["replaced_by_higher_seq_count"] = replaced_by_higher_seq_count;
    metrics["invalid_peer_drop_count"] = invalid_peer_drop_count;
    metrics["stale_ack_count"] = stale_ack_count;
    metrics["fallback_hold_move_count"] = fallback_hold_move_count;
    return metrics;
}

void QQTNativeInputBuffer::clear() {
    peer_slots.clear();
    frames_by_peer.clear();
    last_input_by_peer.clear();
    last_ack_tick_by_peer.clear();
    last_seq_by_peer.clear();
    latest_seq_by_peer_tick.clear();
    accepted_payload_hash_by_identity.clear();
    accepted_count = 0;
    merged_count = 0;
    stale_seq_drop_count = 0;
    too_late_drop_count = 0;
    late_retarget_count = 0;
    ack_evicted_count = 0;
    fallback_idle_count = 0;
    duplicate_ignored_count = 0;
    duplicate_conflict_count = 0;
    replaced_by_higher_seq_count = 0;
    invalid_peer_drop_count = 0;
    stale_ack_count = 0;
    fallback_hold_move_count = 0;
}

Dictionary QQTNativeInputBuffer::sanitize_frame(const Dictionary &frame) const {
    Dictionary sanitized = frame.duplicate(true);
    int32_t move_x = int32_t(int64_t(sanitized.get("move_x", 0)));
    int32_t move_y = int32_t(int64_t(sanitized.get("move_y", 0)));
    move_x = std::max(-1, std::min(1, move_x));
    move_y = std::max(-1, std::min(1, move_y));
    if (move_x != 0 && move_y != 0) {
        move_y = 0;
    }
    sanitized["move_x"] = move_x;
    sanitized["move_y"] = move_y;
    sanitized["peer_id"] = int32_t(int64_t(sanitized.get("peer_id", 0)));
    sanitized["tick_id"] = int32_t(int64_t(sanitized.get("tick_id", 0)));
    sanitized["seq"] = int32_t(int64_t(sanitized.get("seq", sanitized.get("tick_id", 0))));

    int32_t action_bits = int32_t(int64_t(sanitized.get("action_bits", 0)));
    action_bits &= 0x7;
    sanitized["action_bits"] = action_bits;

    return sanitized;
}

Dictionary QQTNativeInputBuffer::make_idle_input(int32_t peer_id, int32_t tick_id) const {
    Dictionary idle;
    idle["peer_id"] = peer_id;
    idle["tick_id"] = tick_id;
    idle["seq"] = 0;
    idle["move_x"] = 0;
    idle["move_y"] = 0;
    idle["action_bits"] = 0;
    return idle;
}

Dictionary QQTNativeInputBuffer::fallback_input(int32_t peer_id, int32_t tick_id) {
    const auto last_it = last_input_by_peer.find(peer_id);
    if (last_it == last_input_by_peer.end()) {
        fallback_idle_count += 1;
        return make_idle_input(peer_id, tick_id);
    }
    Dictionary fallback;
    fallback["peer_id"] = peer_id;
    fallback["tick_id"] = tick_id;
    fallback["seq"] = int32_t(int64_t(last_it->second.get("seq", 0)));
    fallback["move_x"] = int32_t(int64_t(last_it->second.get("move_x", 0)));
    fallback["move_y"] = int32_t(int64_t(last_it->second.get("move_y", 0)));
    fallback["action_bits"] = 0;
    fallback_hold_move_count += 1;
    return fallback;
}

void QQTNativeInputBuffer::evict_old_ticks(int32_t peer_id, int32_t current_tick) {
    auto peer_it = frames_by_peer.find(peer_id);
    if (peer_it == frames_by_peer.end()) {
        return;
    }
    const int32_t min_tick = current_tick - tick_capacity;
    for (auto it = peer_it->second.begin(); it != peer_it->second.end();) {
        if (it->first < min_tick) {
            const int32_t evicted_tick = it->first;
            latest_seq_by_peer_tick[peer_id].erase(evicted_tick);
            for (auto id_it = accepted_payload_hash_by_identity.begin(); id_it != accepted_payload_hash_by_identity.end();) {
                if (id_it->first.peer_id == peer_id && id_it->first.tick_id == evicted_tick) {
                    id_it = accepted_payload_hash_by_identity.erase(id_it);
                } else {
                    ++id_it;
                }
            }
            it = peer_it->second.erase(it);
            ack_evicted_count += 1;
        } else {
            ++it;
        }
    }
}
