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
    int32_t native_decode_count = 0;
    int32_t json_decode_count = 0;
    int32_t malformed_count = 0;

protected:
    static void _bind_methods();

public:
    String get_kernel_version() const;
    PackedByteArray encode_message(const Dictionary &message) const;
    Dictionary decode_message(const PackedByteArray &payload);
    bool is_native_payload(const PackedByteArray &payload) const;
    Dictionary get_metrics() const;
    void reset_metrics();
};
