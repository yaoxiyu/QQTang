#include "sync/native_authority_batch_coalescer.h"

#include "sync/sync_kernel_version.h"

#include <godot_cpp/classes/time.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/variant.hpp>

#include <algorithm>
#include <map>
#include <set>

namespace {
constexpr const char *TYPE_INPUT_ACK = "INPUT_ACK";
constexpr const char *TYPE_STATE_SUMMARY = "STATE_SUMMARY";
constexpr const char *TYPE_CHECKPOINT = "CHECKPOINT";
constexpr const char *TYPE_AUTHORITATIVE_SNAPSHOT = "AUTHORITATIVE_SNAPSHOT";
constexpr const char *TYPE_MATCH_FINISHED = "MATCH_FINISHED";

String message_type(const Dictionary &message) {
    Variant value = message.get("message_type", Variant());
    if (value.get_type() == Variant::NIL) {
        value = message.get("msg_type", Variant());
    }
    return String(value);
}

int32_t message_tick(const Dictionary &message) {
    Variant value = message.get("tick", Variant());
    if (value.get_type() == Variant::NIL) {
        value = message.get("snapshot_tick", Variant());
    }
    if (value.get_type() == Variant::NIL) {
        value = message.get("ack_tick", 0);
    }
    return int32_t(int64_t(value));
}

bool is_snapshot_type(const String &type) {
    return type == TYPE_CHECKPOINT || type == TYPE_AUTHORITATIVE_SNAPSHOT;
}

bool is_terminal_type(const String &type) {
    return type == TYPE_MATCH_FINISHED;
}

bool is_authority_sync_type(const String &type) {
    return type == TYPE_INPUT_ACK || type == TYPE_STATE_SUMMARY || is_snapshot_type(type) || is_terminal_type(type);
}

Dictionary empty_result() {
    Dictionary result;
    result["input_acks"] = Array();
    result["latest_state_summary"] = Dictionary();
    result["latest_snapshot_message"] = Dictionary();
    result["authority_events_by_tick"] = Array();
    result["terminal_messages"] = Array();
    result["passthrough_messages"] = Array();
    result["dropped_snapshot_ticks"] = PackedInt32Array();
    result["metrics"] = Dictionary();
    return result;
}

String event_id_for(const Dictionary &event, int32_t event_tick, int64_t original_index, int64_t event_index) {
    const String explicit_id = String(event.get("event_id", ""));
    if (!explicit_id.is_empty()) {
        return explicit_id;
    }
    const int32_t event_type = int32_t(int64_t(event.get("event_type", -1)));
    const int32_t source_id = int32_t(int64_t(event.get("source_id", event.get("entity_id", event.get("bubble_id", -1)))));
    const int32_t sequence = int32_t(int64_t(event.get("sequence", event.get("seq", -1))));
    if (source_id >= 0 || sequence >= 0) {
        return String::num_int64(event_tick) + ":" + String::num_int64(event_type) + ":" + String::num_int64(source_id) + ":" + String::num_int64(sequence);
    }
    return String::num_int64(event_tick) + ":" + String::num_int64(event_type) + ":" + String::num_int64(original_index) + ":" + String::num_int64(event_index);
}

int32_t append_events(std::map<int32_t, Array> &events_by_tick, std::set<String> &event_ids, const Dictionary &message, int64_t original_index) {
    Variant raw_events = message.get("events", Variant());
    if (raw_events.get_type() != Variant::ARRAY) {
        return 0;
    }
    Array events = raw_events;
    if (events.is_empty()) {
        return 0;
    }
    const int32_t fallback_tick = message_tick(message);
    int32_t appended_count = 0;
    for (int64_t event_index = 0; event_index < events.size(); ++event_index) {
        Variant event = events[event_index];
        int32_t event_tick = fallback_tick;
        String event_id;
        if (event.get_type() == Variant::DICTIONARY) {
            Dictionary event_dict = event;
            event_tick = int32_t(int64_t(event_dict.get("tick", fallback_tick)));
            event_id = event_id_for(event_dict, event_tick, original_index, event_index);
        } else {
            event_id = String::num_int64(event_tick) + ":-1:" + String::num_int64(original_index) + ":" + String::num_int64(event_index);
        }
        if (event_ids.find(event_id) != event_ids.end()) {
            continue;
        }
        event_ids.insert(event_id);
        events_by_tick[event_tick].append(event);
        appended_count += 1;
    }
    return appended_count;
}

Array ack_array_from_peer_map(const std::map<int32_t, Dictionary> &ack_by_peer) {
    Array result;
    for (const auto &entry : ack_by_peer) {
        result.append(entry.second.duplicate(true));
    }
    return result;
}

Array events_array_from_tick_map(const std::map<int32_t, Array> &events_by_tick) {
    Array result;
    for (const auto &entry : events_by_tick) {
        Dictionary bucket;
        bucket["tick"] = entry.first;
        bucket["events"] = entry.second.duplicate(true);
        result.append(bucket);
    }
    return result;
}

Dictionary make_metrics(
    int32_t incoming_batch_size,
    int32_t raw_ack_count,
    int32_t raw_summary_count,
    int32_t raw_checkpoint_count,
    int32_t raw_auth_snapshot_count,
    int32_t coalesced_ack_count,
    int32_t coalesced_summary_tick,
    int32_t coalesced_snapshot_tick,
    int32_t dropped_stale_summary_count,
    int32_t dropped_intermediate_summary_count,
    int32_t dropped_stale_snapshot_count,
    int32_t dropped_intermediate_snapshot_count,
    int32_t preserved_event_tick_count,
    int32_t preserved_event_count,
    int32_t terminal_message_count,
    int32_t passthrough_message_count,
    int64_t coalesce_usec
) {
    Dictionary metrics;
    metrics["incoming_batch_size"] = incoming_batch_size;
    metrics["raw_ack_count"] = raw_ack_count;
    metrics["raw_summary_count"] = raw_summary_count;
    metrics["raw_checkpoint_count"] = raw_checkpoint_count;
    metrics["raw_auth_snapshot_count"] = raw_auth_snapshot_count;
    metrics["coalesced_ack_count"] = coalesced_ack_count;
    metrics["coalesced_summary_tick"] = coalesced_summary_tick;
    metrics["coalesced_snapshot_tick"] = coalesced_snapshot_tick;
    metrics["dropped_stale_summary_count"] = dropped_stale_summary_count;
    metrics["dropped_intermediate_summary_count"] = dropped_intermediate_summary_count;
    metrics["dropped_stale_snapshot_count"] = dropped_stale_snapshot_count;
    metrics["dropped_intermediate_snapshot_count"] = dropped_intermediate_snapshot_count;
    metrics["preserved_event_tick_count"] = preserved_event_tick_count;
    metrics["preserved_event_count"] = preserved_event_count;
    metrics["terminal_message_count"] = terminal_message_count;
    metrics["passthrough_message_count"] = passthrough_message_count;
    metrics["coalesce_usec"] = coalesce_usec;
    metrics["native_shadow_equal"] = false;
    metrics["native_shadow_mismatch_count"] = 0;
    return metrics;
}
} // namespace

void QQTNativeAuthorityBatchCoalescer::_bind_methods() {
    ClassDB::bind_method(D_METHOD("get_kernel_version"), &QQTNativeAuthorityBatchCoalescer::get_kernel_version);
    ClassDB::bind_method(D_METHOD("coalesce_client_authority_batch", "messages", "cursor"), &QQTNativeAuthorityBatchCoalescer::coalesce_client_authority_batch);
}

String QQTNativeAuthorityBatchCoalescer::get_kernel_version() const {
    return qqt::sync::SYNC_KERNEL_VERSION;
}

Dictionary QQTNativeAuthorityBatchCoalescer::coalesce_client_authority_batch(const Array &messages, const Dictionary &cursor) const {
    const int64_t started_usec = Time::get_singleton()->get_ticks_usec();
    Dictionary result = empty_result();
    const int32_t known_tick = std::max(
        int32_t(int64_t(cursor.get("latest_authoritative_tick", -1))),
        int32_t(int64_t(cursor.get("latest_snapshot_tick", -1)))
    );
    std::map<int32_t, Dictionary> ack_by_peer;
    std::map<int32_t, Array> events_by_tick;
    std::set<String> event_ids;
    Dictionary summary_message;
    Dictionary snapshot_message;
    int32_t summary_tick = -1;
    int32_t snapshot_tick = -1;
    int32_t raw_ack_count = 0;
    int32_t raw_summary_count = 0;
    int32_t raw_checkpoint_count = 0;
    int32_t raw_auth_snapshot_count = 0;
    int32_t dropped_stale_count = 0;
    int32_t dropped_intermediate_count = 0;
    int32_t dropped_stale_summary_count = 0;
    int32_t dropped_intermediate_summary_count = 0;
    int32_t preserved_event_count = 0;
    PackedInt32Array dropped_snapshot_ticks;

    Array terminal_messages = result["terminal_messages"];
    Array passthrough_messages = result["passthrough_messages"];
    for (int64_t index = 0; index < messages.size(); ++index) {
        Variant raw_message = messages[index];
        if (raw_message.get_type() != Variant::DICTIONARY) {
            continue;
        }
        Dictionary message = raw_message;
        const String type = message_type(message);
        if (is_authority_sync_type(type)) {
            preserved_event_count += append_events(events_by_tick, event_ids, message, index);
        }
        if (type == TYPE_INPUT_ACK) {
            raw_ack_count += 1;
            const int32_t peer_id = int32_t(int64_t(message.get("peer_id", message.get("sender_peer_id", -1))));
            const int32_t ack_tick = int32_t(int64_t(message.get("ack_tick", message.get("tick", 0))));
            auto found = ack_by_peer.find(peer_id);
            if (found == ack_by_peer.end() || ack_tick > int32_t(int64_t(found->second.get("ack_tick", 0)))) {
                Dictionary ack_message = message.duplicate(true);
                ack_message["ack_tick"] = ack_tick;
                ack_message["peer_id"] = peer_id;
                ack_by_peer[peer_id] = ack_message;
            }
        } else if (type == TYPE_STATE_SUMMARY) {
            raw_summary_count += 1;
            const int32_t tick = message_tick(message);
            if (tick <= known_tick) {
                dropped_stale_summary_count += 1;
            } else if (summary_message.is_empty() || tick >= summary_tick) {
                if (!summary_message.is_empty()) {
                    dropped_intermediate_summary_count += 1;
                }
                summary_tick = tick;
                summary_message = message.duplicate(true);
            } else {
                dropped_intermediate_summary_count += 1;
            }
        } else if (is_snapshot_type(type)) {
            if (type == TYPE_CHECKPOINT) {
                raw_checkpoint_count += 1;
            } else {
                raw_auth_snapshot_count += 1;
            }
            const int32_t tick = message_tick(message);
            if (tick <= known_tick) {
                dropped_stale_count += 1;
                dropped_snapshot_ticks.append(tick);
            } else if (snapshot_message.is_empty() || tick >= snapshot_tick) {
                if (!snapshot_message.is_empty()) {
                    dropped_intermediate_count += 1;
                    dropped_snapshot_ticks.append(snapshot_tick);
                }
                snapshot_tick = tick;
                snapshot_message = message.duplicate(true);
            } else {
                dropped_intermediate_count += 1;
                dropped_snapshot_ticks.append(tick);
            }
        } else if (is_terminal_type(type)) {
            terminal_messages.append(message.duplicate(true));
        } else {
            passthrough_messages.append(message.duplicate(true));
        }
    }

    Array input_acks = ack_array_from_peer_map(ack_by_peer);
    Array authority_events = events_array_from_tick_map(events_by_tick);
    result["input_acks"] = input_acks;
    result["latest_state_summary"] = summary_message;
    result["latest_snapshot_message"] = snapshot_message;
    result["authority_events_by_tick"] = authority_events;
    result["terminal_messages"] = terminal_messages;
    result["passthrough_messages"] = passthrough_messages;
    result["dropped_snapshot_ticks"] = dropped_snapshot_ticks;
    result["metrics"] = make_metrics(
        int32_t(messages.size()),
        raw_ack_count,
        raw_summary_count,
        raw_checkpoint_count,
        raw_auth_snapshot_count,
        int32_t(input_acks.size()),
        summary_tick,
        snapshot_tick,
        dropped_stale_summary_count,
        dropped_intermediate_summary_count,
        dropped_stale_count,
        dropped_intermediate_count,
        int32_t(authority_events.size()),
        preserved_event_count,
        int32_t(terminal_messages.size()),
        int32_t(passthrough_messages.size()),
        Time::get_singleton()->get_ticks_usec() - started_usec
    );
    return result;
}
