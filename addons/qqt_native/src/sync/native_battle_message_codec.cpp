#include "sync/native_battle_message_codec.h"

#include "sync/sync_kernel_version.h"

#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

namespace {
constexpr uint8_t MAGIC_0 = 'Q';
constexpr uint8_t MAGIC_1 = 'Q';
constexpr uint8_t MAGIC_2 = 'T';
constexpr uint8_t MAGIC_3 = 'S';
constexpr int32_t HEADER_SIZE = 12;
constexpr uint8_t WIRE_VERSION = 2;
constexpr uint8_t CODE_GENERIC = 0;
constexpr uint8_t CODE_INPUT_BATCH = 1;
constexpr uint8_t CODE_INPUT_ACK = 2;
constexpr uint8_t CODE_STATE_SUMMARY = 3;
constexpr uint8_t CODE_STATE_DELTA = 4;
constexpr uint8_t CODE_CHECKPOINT = 5;
constexpr uint8_t CODE_MATCH_FINISHED = 6;

void append_u8(PackedByteArray &bytes, uint8_t value) {
    bytes.append(value);
}

void append_u16(PackedByteArray &bytes, uint16_t value) {
    bytes.append(uint8_t((value >> 8) & 0xff));
    bytes.append(uint8_t(value & 0xff));
}

void append_i16(PackedByteArray &bytes, int32_t value) {
    append_u16(bytes, uint16_t(int16_t(value)));
}

void append_u32(PackedByteArray &bytes, uint32_t value) {
    bytes.append(uint8_t((value >> 24) & 0xff));
    bytes.append(uint8_t((value >> 16) & 0xff));
    bytes.append(uint8_t((value >> 8) & 0xff));
    bytes.append(uint8_t(value & 0xff));
}

void append_i32(PackedByteArray &bytes, int32_t value) {
    append_u32(bytes, uint32_t(value));
}

uint8_t read_u8(const PackedByteArray &bytes, int32_t &offset) {
    return bytes[offset++];
}

uint16_t read_u16_at(const PackedByteArray &bytes, int32_t offset) {
    return uint16_t((uint16_t(bytes[offset]) << 8) | uint16_t(bytes[offset + 1]));
}

uint16_t read_u16(const PackedByteArray &bytes, int32_t &offset) {
    const uint16_t value = read_u16_at(bytes, offset);
    offset += 2;
    return value;
}

int16_t read_i16(const PackedByteArray &bytes, int32_t &offset) {
    return int16_t(read_u16(bytes, offset));
}

uint32_t read_u32_at(const PackedByteArray &bytes, int32_t offset) {
    return (uint32_t(bytes[offset]) << 24) |
           (uint32_t(bytes[offset + 1]) << 16) |
           (uint32_t(bytes[offset + 2]) << 8) |
           uint32_t(bytes[offset + 3]);
}

uint32_t read_u32(const PackedByteArray &bytes, int32_t &offset) {
    const uint32_t value = read_u32_at(bytes, offset);
    offset += 4;
    return value;
}

int32_t read_i32(const PackedByteArray &bytes, int32_t &offset) {
    return int32_t(read_u32(bytes, offset));
}

int32_t dict_i(const Dictionary &dict, const char *key, int32_t fallback = 0) {
    return int32_t(dict.get(StringName(key), fallback));
}

bool dict_b(const Dictionary &dict, const char *key, bool fallback = false) {
    return bool(dict.get(StringName(key), fallback));
}

Array dict_array(const Dictionary &dict, const char *key) {
    const Variant value = dict.get(StringName(key), Array());
    return value.get_type() == Variant::ARRAY ? Array(value) : Array();
}

Dictionary dict_dict(const Dictionary &dict, const char *key) {
    const Variant value = dict.get(StringName(key), Dictionary());
    return value.get_type() == Variant::DICTIONARY ? Dictionary(value) : Dictionary();
}

uint8_t message_code_for_type(const String &message_type) {
    if (message_type == "INPUT_BATCH") {
        return CODE_INPUT_BATCH;
    }
    if (message_type == "INPUT_ACK") {
        return CODE_INPUT_ACK;
    }
    if (message_type == "STATE_SUMMARY") {
        return CODE_STATE_SUMMARY;
    }
    if (message_type == "STATE_DELTA") {
        return CODE_STATE_DELTA;
    }
    if (message_type == "CHECKPOINT") {
        return CODE_CHECKPOINT;
    }
    if (message_type == "MATCH_FINISHED") {
        return CODE_MATCH_FINISHED;
    }
    return CODE_GENERIC;
}

String message_type_for_code(uint8_t code) {
    switch (code) {
        case CODE_INPUT_BATCH:
            return "INPUT_BATCH";
        case CODE_INPUT_ACK:
            return "INPUT_ACK";
        case CODE_STATE_SUMMARY:
            return "STATE_SUMMARY";
        case CODE_STATE_DELTA:
            return "STATE_DELTA";
        case CODE_CHECKPOINT:
            return "CHECKPOINT";
        case CODE_MATCH_FINISHED:
            return "MATCH_FINISHED";
        default:
            return "";
    }
}

String message_type_from_message(const Dictionary &message) {
    return String(message.get("message_type", Variant()));
}

PackedByteArray wrap_body(uint8_t message_code, const PackedByteArray &body) {
    PackedByteArray bytes;
    bytes.append(MAGIC_0);
    bytes.append(MAGIC_1);
    bytes.append(MAGIC_2);
    bytes.append(MAGIC_3);
    bytes.append(WIRE_VERSION);
    bytes.append(message_code);
    append_u16(bytes, 0);
    append_u32(bytes, uint32_t(body.size()));
    bytes.append_array(body);
    return bytes;
}

bool valid_header(const PackedByteArray &payload, uint8_t expected_code = 255) {
    if (payload.size() < HEADER_SIZE ||
        payload[0] != MAGIC_0 ||
        payload[1] != MAGIC_1 ||
        payload[2] != MAGIC_2 ||
        payload[3] != MAGIC_3 ||
        payload[4] != WIRE_VERSION) {
        return false;
    }
    if (expected_code != 255 && payload[5] != expected_code) {
        return false;
    }
    const uint32_t length = read_u32_at(payload, 8);
    return payload.size() == HEADER_SIZE + int32_t(length);
}

void append_player_summary(PackedByteArray &body, const Dictionary &player) {
    append_u16(body, uint16_t(dict_i(player, "entity_id", 0)));
    append_u8(body, uint8_t(dict_i(player, "player_slot", 0)));
    append_u8(body, dict_b(player, "alive", true) ? 1 : 0);
    append_u8(body, uint8_t(dict_i(player, "life_state", 0)));
    append_i16(body, dict_i(player, "grid_cell_x", 0));
    append_i16(body, dict_i(player, "grid_cell_y", 0));
    append_i16(body, dict_i(player, "move_dir_x", 0));
    append_i16(body, dict_i(player, "move_dir_y", 0));
    append_i16(body, dict_i(player, "move_progress_x", 0));
    append_i16(body, dict_i(player, "move_progress_y", 0));
    append_u8(body, uint8_t(dict_i(player, "facing", 0)));
    append_u8(body, uint8_t(dict_i(player, "move_state", 0)));
    append_u16(body, uint16_t(dict_i(player, "move_remainder_units", 0)));
    append_u8(body, dict_b(player, "last_place_bubble_pressed", false) ? 1 : 0);
    append_u8(body, uint8_t(dict_i(player, "speed_level", 0)));
    append_u8(body, uint8_t(dict_i(player, "bomb_capacity", 0)));
    append_u8(body, uint8_t(dict_i(player, "bomb_available", 0)));
    append_u8(body, uint8_t(dict_i(player, "bomb_range", 0)));
}

Dictionary read_player_summary(const PackedByteArray &payload, int32_t &offset) {
    Dictionary player;
    player["entity_id"] = int32_t(read_u16(payload, offset));
    player["player_slot"] = int32_t(read_u8(payload, offset));
    player["alive"] = read_u8(payload, offset) != 0;
    player["life_state"] = int32_t(read_u8(payload, offset));
    player["grid_cell_x"] = int32_t(read_i16(payload, offset));
    player["grid_cell_y"] = int32_t(read_i16(payload, offset));
    player["move_dir_x"] = int32_t(read_i16(payload, offset));
    player["move_dir_y"] = int32_t(read_i16(payload, offset));
    player["move_progress_x"] = int32_t(read_i16(payload, offset));
    player["move_progress_y"] = int32_t(read_i16(payload, offset));
    player["facing"] = int32_t(read_u8(payload, offset));
    player["move_state"] = int32_t(read_u8(payload, offset));
    player["move_remainder_units"] = int32_t(read_u16(payload, offset));
    player["last_place_bubble_pressed"] = read_u8(payload, offset) != 0;
    player["speed_level"] = int32_t(read_u8(payload, offset));
    player["bomb_capacity"] = int32_t(read_u8(payload, offset));
    player["bomb_available"] = int32_t(read_u8(payload, offset));
    player["bomb_range"] = int32_t(read_u8(payload, offset));
    return player;
}

void append_event(PackedByteArray &body, const Dictionary &event) {
    const Dictionary payload = dict_dict(event, "payload");
    const Array covered_cells = dict_array(payload, "covered_cells");
    append_u32(body, uint32_t(dict_i(event, "tick", 0)));
    append_u16(body, uint16_t(dict_i(event, "event_type", 0)));
    append_i32(body, dict_i(payload, "entity_id", -1));
    append_i32(body, dict_i(payload, "bubble_id", -1));
    append_i32(body, dict_i(payload, "item_id", -1));
    append_i32(body, dict_i(payload, "owner_player_id", -1));
    append_i32(body, dict_i(payload, "player_id", -1));
    append_i16(body, dict_i(payload, "cell_x", -1));
    append_i16(body, dict_i(payload, "cell_y", -1));
    append_u8(body, uint8_t(covered_cells.size()));
    for (int32_t i = 0; i < covered_cells.size(); ++i) {
        if (covered_cells[i].get_type() != Variant::DICTIONARY) {
            append_i16(body, -1);
            append_i16(body, -1);
            continue;
        }
        const Dictionary cell(covered_cells[i]);
        append_i16(body, dict_i(cell, "x", -1));
        append_i16(body, dict_i(cell, "y", -1));
    }
}

Dictionary read_event(const PackedByteArray &payload, int32_t &offset) {
    Dictionary event;
    Dictionary event_payload;
    event["tick"] = int32_t(read_u32(payload, offset));
    event["event_type"] = int32_t(read_u16(payload, offset));
    event_payload["entity_id"] = read_i32(payload, offset);
    event_payload["bubble_id"] = read_i32(payload, offset);
    event_payload["item_id"] = read_i32(payload, offset);
    event_payload["owner_player_id"] = read_i32(payload, offset);
    event_payload["player_id"] = read_i32(payload, offset);
    event_payload["cell_x"] = int32_t(read_i16(payload, offset));
    event_payload["cell_y"] = int32_t(read_i16(payload, offset));
    const uint8_t covered_cell_count = read_u8(payload, offset);
    Array covered_cells;
    for (uint8_t i = 0; i < covered_cell_count; ++i) {
        Dictionary cell;
        cell["x"] = int32_t(read_i16(payload, offset));
        cell["y"] = int32_t(read_i16(payload, offset));
        cell["__type"] = "Vector2i";
        covered_cells.append(cell);
    }
    event_payload["covered_cells"] = covered_cells;
    event["payload"] = event_payload;
    return event;
}

void append_bubble(PackedByteArray &body, const Dictionary &bubble) {
    append_u32(body, uint32_t(dict_i(bubble, "entity_id", 0)));
    append_u16(body, uint16_t(dict_i(bubble, "generation", 1)));
    append_u8(body, dict_b(bubble, "alive", true) ? 1 : 0);
    append_i32(body, dict_i(bubble, "owner_player_id", -1));
    append_u8(body, uint8_t(dict_i(bubble, "bubble_type", 0)));
    append_i16(body, dict_i(bubble, "cell_x", 0));
    append_i16(body, dict_i(bubble, "cell_y", 0));
    append_u32(body, uint32_t(dict_i(bubble, "spawn_tick", 0)));
    append_u32(body, uint32_t(dict_i(bubble, "explode_tick", 0)));
    append_u16(body, uint16_t(dict_i(bubble, "bubble_range", 1)));
    append_u8(body, uint8_t(dict_i(bubble, "moving_state", 0)));
    append_i16(body, dict_i(bubble, "move_dir_x", 0));
    append_i16(body, dict_i(bubble, "move_dir_y", 0));
    append_u8(body, dict_b(bubble, "pierce", false) ? 1 : 0);
    append_u8(body, dict_b(bubble, "chain_triggered", false) ? 1 : 0);
    append_u32(body, uint32_t(dict_i(bubble, "remote_group_id", 0)));
}

Dictionary read_bubble(const PackedByteArray &payload, int32_t &offset) {
    Dictionary bubble;
    bubble["entity_id"] = int32_t(read_u32(payload, offset));
    bubble["generation"] = int32_t(read_u16(payload, offset));
    bubble["alive"] = read_u8(payload, offset) != 0;
    bubble["owner_player_id"] = read_i32(payload, offset);
    bubble["bubble_type"] = int32_t(read_u8(payload, offset));
    bubble["cell_x"] = int32_t(read_i16(payload, offset));
    bubble["cell_y"] = int32_t(read_i16(payload, offset));
    bubble["spawn_tick"] = int32_t(read_u32(payload, offset));
    bubble["explode_tick"] = int32_t(read_u32(payload, offset));
    bubble["bubble_range"] = int32_t(read_u16(payload, offset));
    bubble["moving_state"] = int32_t(read_u8(payload, offset));
    bubble["move_dir_x"] = int32_t(read_i16(payload, offset));
    bubble["move_dir_y"] = int32_t(read_i16(payload, offset));
    bubble["pierce"] = read_u8(payload, offset) != 0;
    bubble["chain_triggered"] = read_u8(payload, offset) != 0;
    bubble["remote_group_id"] = int32_t(read_u32(payload, offset));
    return bubble;
}

void append_item(PackedByteArray &body, const Dictionary &item) {
    append_u32(body, uint32_t(dict_i(item, "entity_id", 0)));
    append_u16(body, uint16_t(dict_i(item, "generation", 1)));
    append_u8(body, dict_b(item, "alive", true) ? 1 : 0);
    append_u8(body, uint8_t(dict_i(item, "item_type", 0)));
    append_i16(body, dict_i(item, "cell_x", 0));
    append_i16(body, dict_i(item, "cell_y", 0));
    append_u32(body, uint32_t(dict_i(item, "spawn_tick", 0)));
    append_u16(body, uint16_t(dict_i(item, "pickup_delay_ticks", 0)));
    append_u8(body, dict_b(item, "visible", true) ? 1 : 0);
}

Dictionary read_item(const PackedByteArray &payload, int32_t &offset) {
    Dictionary item;
    item["entity_id"] = int32_t(read_u32(payload, offset));
    item["generation"] = int32_t(read_u16(payload, offset));
    item["alive"] = read_u8(payload, offset) != 0;
    item["item_type"] = int32_t(read_u8(payload, offset));
    item["cell_x"] = int32_t(read_i16(payload, offset));
    item["cell_y"] = int32_t(read_i16(payload, offset));
    item["spawn_tick"] = int32_t(read_u32(payload, offset));
    item["pickup_delay_ticks"] = int32_t(read_u16(payload, offset));
    item["visible"] = read_u8(payload, offset) != 0;
    return item;
}

bool has_remaining(const PackedByteArray &payload, int32_t offset, int32_t bytes) {
    return offset + bytes <= payload.size();
}

void append_ack_by_peer(PackedByteArray &body, const Dictionary &ack_by_peer) {
    const Array keys = ack_by_peer.keys();
    const int32_t count = keys.size() > 255 ? 255 : keys.size();
    append_u8(body, uint8_t(count));
    for (int32_t i = 0; i < count; ++i) {
        const Variant key = keys[i];
        const int32_t peer_id = int32_t(key);
        const int32_t ack_tick = int32_t(ack_by_peer.get(key, 0));
        append_u32(body, uint32_t(peer_id));
        append_u32(body, uint32_t(ack_tick));
    }
}

Dictionary read_ack_by_peer(const PackedByteArray &payload, int32_t &offset) {
    Dictionary ack_by_peer;
    if (!has_remaining(payload, offset, 1)) {
        return ack_by_peer;
    }
    const uint8_t count = read_u8(payload, offset);
    if (!has_remaining(payload, offset, int32_t(count) * 8)) {
        return Dictionary();
    }
    for (uint8_t i = 0; i < count; ++i) {
        const int32_t peer_id = int32_t(read_u32(payload, offset));
        const int32_t ack_tick = int32_t(read_u32(payload, offset));
        ack_by_peer[peer_id] = ack_tick;
    }
    return ack_by_peer;
}
} // namespace

void QQTNativeBattleMessageCodec::_bind_methods() {
    ClassDB::bind_method(D_METHOD("get_kernel_version"), &QQTNativeBattleMessageCodec::get_kernel_version);
    ClassDB::bind_method(D_METHOD("encode_message", "message"), &QQTNativeBattleMessageCodec::encode_message);
    ClassDB::bind_method(D_METHOD("decode_message", "payload"), &QQTNativeBattleMessageCodec::decode_message);
    ClassDB::bind_method(D_METHOD("encode_input_batch_v2", "message"), &QQTNativeBattleMessageCodec::encode_input_batch_v2);
    ClassDB::bind_method(D_METHOD("decode_input_batch_v2", "payload"), &QQTNativeBattleMessageCodec::decode_input_batch_v2);
    ClassDB::bind_method(D_METHOD("encode_state_summary_v2", "message"), &QQTNativeBattleMessageCodec::encode_state_summary_v2);
    ClassDB::bind_method(D_METHOD("decode_state_summary_v2", "payload"), &QQTNativeBattleMessageCodec::decode_state_summary_v2);
    ClassDB::bind_method(D_METHOD("encode_state_delta_v2", "message"), &QQTNativeBattleMessageCodec::encode_state_delta_v2);
    ClassDB::bind_method(D_METHOD("decode_state_delta_v2", "payload"), &QQTNativeBattleMessageCodec::decode_state_delta_v2);
    ClassDB::bind_method(D_METHOD("detect_message_type", "payload"), &QQTNativeBattleMessageCodec::detect_message_type);
    ClassDB::bind_method(D_METHOD("is_native_payload", "payload"), &QQTNativeBattleMessageCodec::is_native_payload);
    ClassDB::bind_method(D_METHOD("get_metrics"), &QQTNativeBattleMessageCodec::get_metrics);
    ClassDB::bind_method(D_METHOD("reset_metrics"), &QQTNativeBattleMessageCodec::reset_metrics);
}

String QQTNativeBattleMessageCodec::get_kernel_version() const {
    return qqt::sync::SYNC_KERNEL_VERSION;
}

PackedByteArray QQTNativeBattleMessageCodec::encode_message(const Dictionary &message) const {
    const String message_type = message_type_from_message(message);
    const uint8_t code = message_code_for_type(message_type);
    if (code == CODE_INPUT_BATCH || code == CODE_STATE_SUMMARY || code == CODE_STATE_DELTA) {
        malformed_count += 1;
        return PackedByteArray();
    }
    PackedByteArray body = UtilityFunctions::var_to_bytes(message);
    return wrap_body(code, body);
}

Dictionary QQTNativeBattleMessageCodec::decode_message(const PackedByteArray &payload) {
    if (!valid_header(payload)) {
        malformed_count += 1;
        return Dictionary();
    }
    const uint8_t code = payload[5];
    if (code == CODE_INPUT_BATCH) {
        return decode_input_batch_v2(payload);
    }
    if (code == CODE_STATE_SUMMARY) {
        return decode_state_summary_v2(payload);
    }
    if (code == CODE_STATE_DELTA) {
        return decode_state_delta_v2(payload);
    }
    const uint32_t length = read_u32_at(payload, 8);
    PackedByteArray body;
    for (int32_t i = 0; i < int32_t(length); ++i) {
        body.append(payload[HEADER_SIZE + i]);
    }
    Variant decoded = UtilityFunctions::bytes_to_var(body);
    if (decoded.get_type() != Variant::DICTIONARY) {
        malformed_count += 1;
        return Dictionary();
    }
    native_decode_count += 1;
    return Dictionary(decoded);
}

PackedByteArray QQTNativeBattleMessageCodec::encode_input_batch_v2(const Dictionary &message) const {
    PackedByteArray body;
    const Array frames = dict_array(message, "frames");
    append_u8(body, uint8_t(dict_i(message, "protocol_version", 0)));
    append_u32(body, uint32_t(dict_i(message, "peer_id", 0)));
    append_u32(body, uint32_t(dict_i(message, "controlled_peer_id", 0)));
    append_u32(body, uint32_t(dict_i(message, "client_batch_seq", 0)));
    append_u32(body, uint32_t(dict_i(message, "ack_base_tick", 0)));
    append_u32(body, uint32_t(dict_i(message, "first_tick", 0)));
    append_u32(body, uint32_t(dict_i(message, "latest_tick", 0)));
    append_u8(body, uint8_t(frames.size()));
    append_u8(body, uint8_t(dict_i(message, "flags", 0)));
    for (int32_t i = 0; i < frames.size(); ++i) {
        const Dictionary frame = Dictionary(frames[i]);
        append_u16(body, uint16_t(dict_i(frame, "tick_delta", 0)));
        append_u16(body, uint16_t(dict_i(frame, "seq", 0)));
        const int32_t move_x_code = dict_i(frame, "move_x", 0) + 1;
        const int32_t move_y_code = dict_i(frame, "move_y", 0) + 1;
        append_u8(body, uint8_t((move_x_code & 0x3) | ((move_y_code & 0x3) << 2)));
        append_u16(body, uint16_t(dict_i(frame, "action_bits", 0)));
        append_u8(body, uint8_t(dict_i(frame, "flags", 0)));
    }
    input_batch_v2_encode_count += 1;
    return wrap_body(CODE_INPUT_BATCH, body);
}

Dictionary QQTNativeBattleMessageCodec::decode_input_batch_v2(const PackedByteArray &payload) {
    if (!valid_header(payload, CODE_INPUT_BATCH)) {
        malformed_count += 1;
        return Dictionary();
    }
    int32_t offset = HEADER_SIZE;
    if (!has_remaining(payload, offset, 27)) {
        malformed_count += 1;
        return Dictionary();
    }
    Dictionary message;
    message["message_type"] = "INPUT_BATCH";
    message["wire_version"] = int32_t(WIRE_VERSION);
    message["protocol_version"] = int32_t(read_u8(payload, offset));
    message["peer_id"] = int32_t(read_u32(payload, offset));
    message["controlled_peer_id"] = int32_t(read_u32(payload, offset));
    message["client_batch_seq"] = int32_t(read_u32(payload, offset));
    message["ack_base_tick"] = int32_t(read_u32(payload, offset));
    message["first_tick"] = int32_t(read_u32(payload, offset));
    message["latest_tick"] = int32_t(read_u32(payload, offset));
    const uint8_t frame_count = read_u8(payload, offset);
    message["flags"] = int32_t(read_u8(payload, offset));
    Array frames;
    for (uint8_t i = 0; i < frame_count; ++i) {
        if (!has_remaining(payload, offset, 8)) {
            malformed_count += 1;
            return Dictionary();
        }
        Dictionary frame;
        frame["tick_delta"] = int32_t(read_u16(payload, offset));
        frame["seq"] = int32_t(read_u16(payload, offset));
        const uint8_t move_bits = read_u8(payload, offset);
        frame["move_x"] = int32_t(move_bits & 0x3) - 1;
        frame["move_y"] = int32_t((move_bits >> 2) & 0x3) - 1;
        frame["action_bits"] = int32_t(read_u16(payload, offset));
        frame["flags"] = int32_t(read_u8(payload, offset));
        frames.append(frame);
    }
    message["frame_count"] = int32_t(frame_count);
    message["frames"] = frames;
    input_batch_v2_decode_count += 1;
    native_decode_count += 1;
    return message;
}

PackedByteArray QQTNativeBattleMessageCodec::encode_state_summary_v2(const Dictionary &message) const {
    PackedByteArray body;
    const Array players = dict_array(message, "player_summary");
    const Array events = dict_array(message, "events");
    append_u32(body, uint32_t(dict_i(message, "tick", 0)));
    append_u32(body, uint32_t(dict_i(message, "checksum", 0)));
    append_u8(body, uint8_t(dict_i(message, "match_phase", 0)));
    append_u32(body, uint32_t(dict_i(message, "remaining_ticks", 0)));
    append_u8(body, uint8_t(players.size()));
    for (int32_t i = 0; i < players.size(); ++i) {
        append_player_summary(body, Dictionary(players[i]));
    }
    append_u8(body, uint8_t(events.size()));
    for (int32_t i = 0; i < events.size(); ++i) {
        append_event(body, Dictionary(events[i]));
    }
    append_ack_by_peer(body, dict_dict(message, "ack_by_peer"));
    state_summary_v2_encode_count += 1;
    return wrap_body(CODE_STATE_SUMMARY, body);
}

Dictionary QQTNativeBattleMessageCodec::decode_state_summary_v2(const PackedByteArray &payload) {
    if (!valid_header(payload, CODE_STATE_SUMMARY)) {
        malformed_count += 1;
        return Dictionary();
    }
    int32_t offset = HEADER_SIZE;
    if (!has_remaining(payload, offset, 14)) {
        malformed_count += 1;
        return Dictionary();
    }
    Dictionary message;
    message["message_type"] = "STATE_SUMMARY";
    message["wire_version"] = int32_t(WIRE_VERSION);
    message["tick"] = int32_t(read_u32(payload, offset));
    message["checksum"] = int32_t(read_u32(payload, offset));
    message["match_phase"] = int32_t(read_u8(payload, offset));
    message["remaining_ticks"] = int32_t(read_u32(payload, offset));
    const uint8_t player_count = read_u8(payload, offset);
    Array players;
    for (uint8_t i = 0; i < player_count; ++i) {
        if (!has_remaining(payload, offset, 27)) {
            malformed_count += 1;
            return Dictionary();
        }
        players.append(read_player_summary(payload, offset));
    }
    if (!has_remaining(payload, offset, 1)) {
        malformed_count += 1;
        return Dictionary();
    }
    const uint8_t event_count = read_u8(payload, offset);
    Array events;
    for (uint8_t i = 0; i < event_count; ++i) {
        if (!has_remaining(payload, offset, 31)) {
            malformed_count += 1;
            return Dictionary();
        }
        const uint8_t covered_cell_count = uint8_t(payload[offset + 30]);
        if (!has_remaining(payload, offset, 31 + int32_t(covered_cell_count) * 4)) {
            malformed_count += 1;
            return Dictionary();
        }
        events.append(read_event(payload, offset));
    }
    Dictionary ack_by_peer;
    if (has_remaining(payload, offset, 1)) {
        ack_by_peer = read_ack_by_peer(payload, offset);
        if (ack_by_peer.is_empty() && offset < payload.size()) {
            malformed_count += 1;
            return Dictionary();
        }
    }
    message["player_summary"] = players;
    message["events"] = events;
    if (!ack_by_peer.is_empty()) {
        message["ack_by_peer"] = ack_by_peer;
    }
    state_summary_v2_decode_count += 1;
    native_decode_count += 1;
    return message;
}

PackedByteArray QQTNativeBattleMessageCodec::encode_state_delta_v2(const Dictionary &message) const {
    PackedByteArray body;
    const Array changed_bubbles = dict_array(message, "changed_bubbles");
    const Array removed_bubble_ids = dict_array(message, "removed_bubble_ids");
    const Array changed_items = dict_array(message, "changed_items");
    const Array removed_item_ids = dict_array(message, "removed_item_ids");
    const Array event_details = dict_array(message, "event_details");
    append_u32(body, uint32_t(dict_i(message, "tick", 0)));
    append_u32(body, uint32_t(dict_i(message, "base_tick", 0)));
    append_u8(body, uint8_t(changed_bubbles.size()));
    for (int32_t i = 0; i < changed_bubbles.size(); ++i) {
        append_bubble(body, Dictionary(changed_bubbles[i]));
    }
    append_u8(body, uint8_t(removed_bubble_ids.size()));
    for (int32_t i = 0; i < removed_bubble_ids.size(); ++i) {
        append_u32(body, uint32_t(int32_t(removed_bubble_ids[i])));
    }
    append_u8(body, uint8_t(changed_items.size()));
    for (int32_t i = 0; i < changed_items.size(); ++i) {
        append_item(body, Dictionary(changed_items[i]));
    }
    append_u8(body, uint8_t(removed_item_ids.size()));
    for (int32_t i = 0; i < removed_item_ids.size(); ++i) {
        append_u32(body, uint32_t(int32_t(removed_item_ids[i])));
    }
    append_u8(body, uint8_t(event_details.size()));
    for (int32_t i = 0; i < event_details.size(); ++i) {
        append_event(body, Dictionary(event_details[i]));
    }
    state_delta_v2_encode_count += 1;
    return wrap_body(CODE_STATE_DELTA, body);
}

Dictionary QQTNativeBattleMessageCodec::decode_state_delta_v2(const PackedByteArray &payload) {
    if (!valid_header(payload, CODE_STATE_DELTA)) {
        malformed_count += 1;
        return Dictionary();
    }
    int32_t offset = HEADER_SIZE;
    if (!has_remaining(payload, offset, 9)) {
        malformed_count += 1;
        return Dictionary();
    }
    Dictionary message;
    message["message_type"] = "STATE_DELTA";
    message["wire_version"] = int32_t(WIRE_VERSION);
    message["tick"] = int32_t(read_u32(payload, offset));
    message["base_tick"] = int32_t(read_u32(payload, offset));
    Array changed_bubbles;
    const uint8_t changed_bubble_count = read_u8(payload, offset);
    for (uint8_t i = 0; i < changed_bubble_count; ++i) {
        if (!has_remaining(payload, offset, 38)) {
            malformed_count += 1;
            return Dictionary();
        }
        changed_bubbles.append(read_bubble(payload, offset));
    }
    Array removed_bubble_ids;
    const uint8_t removed_bubble_count = read_u8(payload, offset);
    for (uint8_t i = 0; i < removed_bubble_count; ++i) {
        removed_bubble_ids.append(int32_t(read_u32(payload, offset)));
    }
    Array changed_items;
    const uint8_t changed_item_count = read_u8(payload, offset);
    for (uint8_t i = 0; i < changed_item_count; ++i) {
        if (!has_remaining(payload, offset, 19)) {
            malformed_count += 1;
            return Dictionary();
        }
        changed_items.append(read_item(payload, offset));
    }
    Array removed_item_ids;
    const uint8_t removed_item_count = read_u8(payload, offset);
    for (uint8_t i = 0; i < removed_item_count; ++i) {
        removed_item_ids.append(int32_t(read_u32(payload, offset)));
    }
    Array event_details;
    const uint8_t event_count = read_u8(payload, offset);
    for (uint8_t i = 0; i < event_count; ++i) {
        if (!has_remaining(payload, offset, 31)) {
            malformed_count += 1;
            return Dictionary();
        }
        const uint8_t covered_cell_count = uint8_t(payload[offset + 30]);
        if (!has_remaining(payload, offset, 31 + int32_t(covered_cell_count) * 4)) {
            malformed_count += 1;
            return Dictionary();
        }
        event_details.append(read_event(payload, offset));
    }
    message["changed_bubbles"] = changed_bubbles;
    message["removed_bubble_ids"] = removed_bubble_ids;
    message["changed_items"] = changed_items;
    message["removed_item_ids"] = removed_item_ids;
    message["event_details"] = event_details;
    message["events"] = event_details;
    state_delta_v2_decode_count += 1;
    native_decode_count += 1;
    return message;
}

String QQTNativeBattleMessageCodec::detect_message_type(const PackedByteArray &payload) const {
    if (!valid_header(payload)) {
        return "";
    }
    return message_type_for_code(payload[5]);
}

bool QQTNativeBattleMessageCodec::is_native_payload(const PackedByteArray &payload) const {
    return payload.size() >= 4 &&
           payload[0] == MAGIC_0 &&
           payload[1] == MAGIC_1 &&
           payload[2] == MAGIC_2 &&
           payload[3] == MAGIC_3;
}

Dictionary QQTNativeBattleMessageCodec::get_metrics() const {
    Dictionary metrics;
    metrics["native_decode_count"] = native_decode_count;
    metrics["json_decode_count"] = json_decode_count;
    metrics["malformed_count"] = malformed_count;
    metrics["input_batch_v2_encode_count"] = input_batch_v2_encode_count;
    metrics["input_batch_v2_decode_count"] = input_batch_v2_decode_count;
    metrics["state_summary_v2_encode_count"] = state_summary_v2_encode_count;
    metrics["state_summary_v2_decode_count"] = state_summary_v2_decode_count;
    metrics["state_delta_v2_encode_count"] = state_delta_v2_encode_count;
    metrics["state_delta_v2_decode_count"] = state_delta_v2_decode_count;
    return metrics;
}

void QQTNativeBattleMessageCodec::reset_metrics() {
    native_decode_count = 0;
    json_decode_count = 0;
    malformed_count = 0;
    input_batch_v2_encode_count = 0;
    input_batch_v2_decode_count = 0;
    state_summary_v2_encode_count = 0;
    state_summary_v2_decode_count = 0;
    state_delta_v2_encode_count = 0;
    state_delta_v2_decode_count = 0;
}
