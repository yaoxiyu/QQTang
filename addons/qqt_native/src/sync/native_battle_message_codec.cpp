#include "sync/native_battle_message_codec.h"

#include "sync/sync_kernel_version.h"

#include <godot_cpp/variant/utility_functions.hpp>

namespace {
constexpr uint8_t MAGIC_0 = 'Q';
constexpr uint8_t MAGIC_1 = 'Q';
constexpr uint8_t MAGIC_2 = 'T';
constexpr uint8_t MAGIC_3 = 'S';
constexpr int32_t HEADER_SIZE = 12;
constexpr int32_t WIRE_VERSION = 1;

void append_u16(PackedByteArray &bytes, uint16_t value) {
    bytes.append(uint8_t((value >> 8) & 0xff));
    bytes.append(uint8_t(value & 0xff));
}

void append_u32(PackedByteArray &bytes, uint32_t value) {
    bytes.append(uint8_t((value >> 24) & 0xff));
    bytes.append(uint8_t((value >> 16) & 0xff));
    bytes.append(uint8_t((value >> 8) & 0xff));
    bytes.append(uint8_t(value & 0xff));
}

uint16_t read_u16(const PackedByteArray &bytes, int32_t offset) {
    return uint16_t((uint16_t(bytes[offset]) << 8) | uint16_t(bytes[offset + 1]));
}

uint32_t read_u32(const PackedByteArray &bytes, int32_t offset) {
    return (uint32_t(bytes[offset]) << 24) |
           (uint32_t(bytes[offset + 1]) << 16) |
           (uint32_t(bytes[offset + 2]) << 8) |
           uint32_t(bytes[offset + 3]);
}
} // namespace

void QQTNativeBattleMessageCodec::_bind_methods() {
    ClassDB::bind_method(D_METHOD("get_kernel_version"), &QQTNativeBattleMessageCodec::get_kernel_version);
    ClassDB::bind_method(D_METHOD("encode_message", "message"), &QQTNativeBattleMessageCodec::encode_message);
    ClassDB::bind_method(D_METHOD("decode_message", "payload"), &QQTNativeBattleMessageCodec::decode_message);
    ClassDB::bind_method(D_METHOD("is_native_payload", "payload"), &QQTNativeBattleMessageCodec::is_native_payload);
    ClassDB::bind_method(D_METHOD("get_metrics"), &QQTNativeBattleMessageCodec::get_metrics);
    ClassDB::bind_method(D_METHOD("reset_metrics"), &QQTNativeBattleMessageCodec::reset_metrics);
}

String QQTNativeBattleMessageCodec::get_kernel_version() const {
    return qqt::sync::SYNC_KERNEL_VERSION;
}

PackedByteArray QQTNativeBattleMessageCodec::encode_message(const Dictionary &message) const {
    PackedByteArray body = UtilityFunctions::var_to_bytes(message);
    PackedByteArray bytes;
    bytes.append(MAGIC_0);
    bytes.append(MAGIC_1);
    bytes.append(MAGIC_2);
    bytes.append(MAGIC_3);
    append_u16(bytes, WIRE_VERSION);
    append_u16(bytes, 0);
    append_u32(bytes, uint32_t(body.size()));
    bytes.append_array(body);
    return bytes;
}

Dictionary QQTNativeBattleMessageCodec::decode_message(const PackedByteArray &payload) {
    if (!is_native_payload(payload) || payload.size() < HEADER_SIZE) {
        malformed_count += 1;
        return Dictionary();
    }
    const uint16_t version = read_u16(payload, 4);
    const uint32_t length = read_u32(payload, 8);
    if (version != WIRE_VERSION || payload.size() != HEADER_SIZE + int32_t(length)) {
        malformed_count += 1;
        return Dictionary();
    }
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
    return metrics;
}

void QQTNativeBattleMessageCodec::reset_metrics() {
    native_decode_count = 0;
    json_decode_count = 0;
    malformed_count = 0;
}
