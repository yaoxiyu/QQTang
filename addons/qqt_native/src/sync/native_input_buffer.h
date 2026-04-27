#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/string.hpp>

#include <map>
#include <set>

using namespace godot;

struct QQTInputIdentity {
    int32_t peer_id = 0;
    int32_t tick_id = 0;
    int32_t seq = 0;
};

struct QQTInputIdentityLess {
    bool operator()(const QQTInputIdentity &a, const QQTInputIdentity &b) const {
        if (a.peer_id != b.peer_id) return a.peer_id < b.peer_id;
        if (a.tick_id != b.tick_id) return a.tick_id < b.tick_id;
        return a.seq < b.seq;
    }
};

class QQTNativeInputBuffer : public RefCounted {
    GDCLASS(QQTNativeInputBuffer, RefCounted);

private:
    int32_t peer_capacity = 8;
    int32_t tick_capacity = 64;
    int32_t max_late_ticks = 2;
    std::map<int32_t, int32_t> peer_slots;
    std::map<int32_t, std::map<int32_t, Dictionary>> frames_by_peer;
    std::map<int32_t, Dictionary> last_input_by_peer;
    std::map<int32_t, int32_t> last_ack_tick_by_peer;
    std::map<int32_t, int32_t> last_seq_by_peer;
    std::map<int32_t, std::map<int32_t, int32_t>> latest_seq_by_peer_tick;
    std::map<QQTInputIdentity, uint32_t, QQTInputIdentityLess> accepted_payload_hash_by_identity;
    int32_t accepted_count = 0;
    int32_t merged_count = 0;
    int32_t stale_seq_drop_count = 0;
    int32_t too_late_drop_count = 0;
    int32_t late_retarget_count = 0;
    int32_t ack_evicted_count = 0;
    int32_t fallback_idle_count = 0;
    int32_t duplicate_ignored_count = 0;
    int32_t duplicate_conflict_count = 0;
    int32_t replaced_by_higher_seq_count = 0;
    int32_t invalid_peer_drop_count = 0;
    int32_t stale_ack_count = 0;
    int32_t fallback_hold_move_count = 0;

protected:
    static void _bind_methods();

public:
    String get_kernel_version() const;
    void configure(int32_t p_peer_capacity, int32_t p_tick_capacity, int32_t p_max_late_ticks);
    void register_peer(int32_t peer_id, int32_t player_slot);
    Dictionary push_input(const Dictionary &frame, int32_t authority_tick);
    Array collect_inputs_for_tick(const Array &peer_ids, int32_t tick_id);
    void ack_peer(int32_t peer_id, int32_t ack_tick);
    Dictionary get_metrics() const;
    void clear();

private:
    Dictionary sanitize_frame(const Dictionary &frame) const;
    Dictionary make_idle_input(int32_t peer_id, int32_t tick_id) const;
    Dictionary fallback_input(int32_t peer_id, int32_t tick_id);
    uint32_t input_payload_hash(const Dictionary &frame) const;
    void evict_old_ticks(int32_t peer_id, int32_t current_tick);
};
