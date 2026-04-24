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

Dictionary QQTNativeInputBuffer::push_input(const Dictionary &frame, int32_t authority_tick) {
    Dictionary result;
    if (frame.is_empty()) {
        result["status"] = "drop_empty";
        return result;
    }
    Dictionary sanitized = sanitize_frame(frame);
    const int32_t peer_id = int32_t(int64_t(sanitized.get("peer_id", 0)));
    int32_t tick_id = int32_t(int64_t(sanitized.get("tick_id", 0)));
    const int32_t seq = int32_t(int64_t(sanitized.get("seq", tick_id)));
    const auto last_seq_it = last_seq_by_peer.find(peer_id);
    if (last_seq_it != last_seq_by_peer.end() && seq < last_seq_it->second) {
        stale_seq_drop_count += 1;
        result["status"] = "drop_stale_seq";
        result["tick_id"] = tick_id;
        result["seq"] = seq;
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
        tick_id = authority_tick + 1;
        sanitized["tick_id"] = tick_id;
        late_retarget_count += 1;
        result["retargeted"] = true;
    } else {
        result["retargeted"] = false;
    }

    std::map<int32_t, Dictionary> &peer_frames = frames_by_peer[peer_id];
    auto existing_it = peer_frames.find(tick_id);
    if (existing_it != peer_frames.end()) {
        merge_input_frame(existing_it->second, sanitized);
        last_input_by_peer[peer_id] = existing_it->second;
        merged_count += 1;
        result["status"] = "merged";
    } else {
        peer_frames[tick_id] = sanitized;
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

Array QQTNativeInputBuffer::collect_inputs_for_tick(const Array &peer_ids, int32_t tick_id) const {
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
    last_ack_tick_by_peer[peer_id] = ack_tick;
    auto peer_it = frames_by_peer.find(peer_id);
    if (peer_it == frames_by_peer.end()) {
        return;
    }
    for (auto it = peer_it->second.begin(); it != peer_it->second.end();) {
        if (it->first <= ack_tick) {
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
    metrics["merged_count"] = merged_count;
    metrics["stale_seq_drop_count"] = stale_seq_drop_count;
    metrics["too_late_drop_count"] = too_late_drop_count;
    metrics["late_retarget_count"] = late_retarget_count;
    metrics["ack_evicted_count"] = ack_evicted_count;
    metrics["fallback_idle_count"] = fallback_idle_count;
    return metrics;
}

void QQTNativeInputBuffer::clear() {
    peer_slots.clear();
    frames_by_peer.clear();
    last_input_by_peer.clear();
    last_ack_tick_by_peer.clear();
    last_seq_by_peer.clear();
    accepted_count = 0;
    merged_count = 0;
    stale_seq_drop_count = 0;
    too_late_drop_count = 0;
    late_retarget_count = 0;
    ack_evicted_count = 0;
    fallback_idle_count = 0;
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
    sanitized["action_place"] = bool(sanitized.get("action_place", false));
    sanitized["action_skill1"] = bool(sanitized.get("action_skill1", false));
    sanitized["action_skill2"] = bool(sanitized.get("action_skill2", false));
    return sanitized;
}

Dictionary QQTNativeInputBuffer::make_idle_input(int32_t peer_id, int32_t tick_id) const {
    Dictionary idle;
    idle["peer_id"] = peer_id;
    idle["tick_id"] = tick_id;
    idle["seq"] = 0;
    idle["move_x"] = 0;
    idle["move_y"] = 0;
    idle["action_place"] = false;
    idle["action_skill1"] = false;
    idle["action_skill2"] = false;
    return idle;
}

Dictionary QQTNativeInputBuffer::fallback_input(int32_t peer_id, int32_t tick_id) const {
    const auto last_it = last_input_by_peer.find(peer_id);
    if (last_it == last_input_by_peer.end()) {
        return make_idle_input(peer_id, tick_id);
    }
    Dictionary fallback;
    fallback["peer_id"] = peer_id;
    fallback["tick_id"] = tick_id;
    fallback["seq"] = int32_t(int64_t(last_it->second.get("seq", 0)));
    fallback["move_x"] = int32_t(int64_t(last_it->second.get("move_x", 0)));
    fallback["move_y"] = int32_t(int64_t(last_it->second.get("move_y", 0)));
    fallback["action_place"] = false;
    fallback["action_skill1"] = false;
    fallback["action_skill2"] = false;
    return fallback;
}

void QQTNativeInputBuffer::merge_input_frame(Dictionary &existing, const Dictionary &incoming) {
    const int32_t incoming_seq = int32_t(int64_t(incoming.get("seq", 0)));
    const int32_t existing_seq = int32_t(int64_t(existing.get("seq", 0)));
    if (incoming_seq >= existing_seq) {
        existing["seq"] = incoming_seq;
        existing["move_x"] = int32_t(int64_t(incoming.get("move_x", 0)));
        existing["move_y"] = int32_t(int64_t(incoming.get("move_y", 0)));
    }
    existing["action_place"] = bool(existing.get("action_place", false)) || bool(incoming.get("action_place", false));
    existing["action_skill1"] = bool(existing.get("action_skill1", false)) || bool(incoming.get("action_skill1", false));
    existing["action_skill2"] = bool(existing.get("action_skill2", false)) || bool(incoming.get("action_skill2", false));
}

void QQTNativeInputBuffer::evict_old_ticks(int32_t peer_id, int32_t current_tick) {
    auto peer_it = frames_by_peer.find(peer_id);
    if (peer_it == frames_by_peer.end()) {
        return;
    }
    const int32_t min_tick = current_tick - tick_capacity;
    for (auto it = peer_it->second.begin(); it != peer_it->second.end();) {
        if (it->first < min_tick) {
            it = peer_it->second.erase(it);
            ack_evicted_count += 1;
        } else {
            ++it;
        }
    }
}
