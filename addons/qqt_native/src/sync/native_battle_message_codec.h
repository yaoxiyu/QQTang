#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/string.hpp>

using namespace godot;

class QQTNativeBattleMessageCodec : public RefCounted {
    GDCLASS(QQTNativeBattleMessageCodec, RefCounted);

private:
    mutable int32_t native_decode_count = 0;
    mutable int32_t json_decode_count = 0;
    mutable int32_t malformed_count = 0;
    mutable int32_t input_batch_v2_encode_count = 0;
    mutable int32_t input_batch_v2_decode_count = 0;
    mutable int32_t state_summary_v2_encode_count = 0;
    mutable int32_t state_summary_v2_decode_count = 0;
    mutable int32_t state_delta_v2_encode_count = 0;
    mutable int32_t state_delta_v2_decode_count = 0;

protected:
    static void _bind_methods();

public:
    String get_kernel_version() const;
    PackedByteArray encode_message(const Dictionary &message) const;
    Dictionary decode_message(const PackedByteArray &payload);
    PackedByteArray encode_input_batch_v2(const Dictionary &message) const;
    Dictionary decode_input_batch_v2(const PackedByteArray &payload);
    PackedByteArray encode_state_summary_v2(const Dictionary &message) const;
    Dictionary decode_state_summary_v2(const PackedByteArray &payload);
    PackedByteArray encode_state_delta_v2(const Dictionary &message) const;
    Dictionary decode_state_delta_v2(const PackedByteArray &payload);
    String detect_message_type(const PackedByteArray &payload) const;
    bool is_native_payload(const PackedByteArray &payload) const;
    Dictionary get_metrics() const;
    void reset_metrics();
};
