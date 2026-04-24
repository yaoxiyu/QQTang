#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/string.hpp>

#include <map>

using namespace godot;

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
    int32_t accepted_count = 0;
    int32_t merged_count = 0;
    int32_t stale_seq_drop_count = 0;
    int32_t too_late_drop_count = 0;
    int32_t late_retarget_count = 0;
    int32_t ack_evicted_count = 0;
    int32_t fallback_idle_count = 0;

protected:
    static void _bind_methods();

public:
    String get_kernel_version() const;
    void configure(int32_t p_peer_capacity, int32_t p_tick_capacity, int32_t p_max_late_ticks);
    void register_peer(int32_t peer_id, int32_t player_slot);
    Dictionary push_input(const Dictionary &frame, int32_t authority_tick);
    Array collect_inputs_for_tick(const Array &peer_ids, int32_t tick_id) const;
    void ack_peer(int32_t peer_id, int32_t ack_tick);
    Dictionary get_metrics() const;
    void clear();

private:
    Dictionary sanitize_frame(const Dictionary &frame) const;
    Dictionary make_idle_input(int32_t peer_id, int32_t tick_id) const;
    Dictionary fallback_input(int32_t peer_id, int32_t tick_id) const;
    void merge_input_frame(Dictionary &existing, const Dictionary &incoming);
    void evict_old_ticks(int32_t peer_id, int32_t current_tick);
};
