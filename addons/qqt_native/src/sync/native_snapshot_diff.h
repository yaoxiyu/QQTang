#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/string.hpp>

using namespace godot;

class QQTNativeSnapshotDiff : public RefCounted {
    GDCLASS(QQTNativeSnapshotDiff, RefCounted);

protected:
    static void _bind_methods();

public:
    String get_kernel_version() const;
    Dictionary diff_snapshots(const Dictionary &local_snapshot, const Dictionary &authority_snapshot, const Dictionary &options) const;
    Dictionary diff_packed_state(const Dictionary &local_packed, const Dictionary &authority_packed, const Dictionary &options) const;
};
