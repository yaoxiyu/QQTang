#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/string.hpp>

using namespace godot;

class QQTNativeRollbackPlanner : public RefCounted {
    GDCLASS(QQTNativeRollbackPlanner, RefCounted);

protected:
    static void _bind_methods();

public:
    enum Decision {
        NOOP = 0,
        ROLLBACK = 1,
        FORCE_RESYNC = 2,
        DROP_STALE_AUTHORITY = 3,
    };

    String get_kernel_version() const;
    Dictionary plan(const Dictionary &cursor, const Dictionary &diff_result) const;
};
