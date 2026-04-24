#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/string.hpp>

using namespace godot;

class QQTNativeAuthorityBatchCoalescer : public RefCounted {
    GDCLASS(QQTNativeAuthorityBatchCoalescer, RefCounted);

protected:
    static void _bind_methods();

public:
    String get_kernel_version() const;
    Dictionary coalesce_client_authority_batch(const Array &messages, const Dictionary &cursor) const;
};
