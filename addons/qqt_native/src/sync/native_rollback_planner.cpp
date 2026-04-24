#include "sync/native_rollback_planner.h"

#include "sync/sync_kernel_version.h"

void QQTNativeRollbackPlanner::_bind_methods() {
    ClassDB::bind_method(D_METHOD("get_kernel_version"), &QQTNativeRollbackPlanner::get_kernel_version);
    ClassDB::bind_method(D_METHOD("plan", "cursor", "diff_result"), &QQTNativeRollbackPlanner::plan);
}

String QQTNativeRollbackPlanner::get_kernel_version() const {
    return qqt::sync::SYNC_KERNEL_VERSION;
}

Dictionary QQTNativeRollbackPlanner::plan(const Dictionary &cursor, const Dictionary &diff_result) const {
    const int32_t authoritative_tick = int32_t(int64_t(cursor.get("authoritative_tick", 0)));
    const int32_t latest_authoritative_tick = int32_t(int64_t(cursor.get("latest_authoritative_tick", -1)));
    const int32_t predicted_until_tick = int32_t(int64_t(cursor.get("predicted_until_tick", authoritative_tick)));
    const int32_t max_rollback_window = int32_t(int64_t(cursor.get("max_rollback_window", 16)));
    const bool local_snapshot_exists = bool(cursor.get("local_snapshot_exists", true));
    const bool force_resync = bool(cursor.get("force_resync", false));
    int32_t decision = NOOP;
    int32_t reason_mask = int32_t(int64_t(diff_result.get("reason_mask", 0)));
    if (authoritative_tick <= latest_authoritative_tick) {
        decision = DROP_STALE_AUTHORITY;
    } else if (!local_snapshot_exists) {
        decision = FORCE_RESYNC;
    } else if (bool(diff_result.get("equal", false))) {
        decision = NOOP;
    } else if (force_resync || predicted_until_tick - authoritative_tick > max_rollback_window) {
        decision = FORCE_RESYNC;
    } else {
        decision = ROLLBACK;
    }
    Dictionary result;
    const int32_t replay_to_tick = predicted_until_tick > authoritative_tick ? predicted_until_tick : authoritative_tick;
    result["decision"] = decision;
    result["rollback_from_tick"] = authoritative_tick;
    result["replay_to_tick"] = replay_to_tick;
    result["replay_tick_count"] = replay_to_tick - authoritative_tick;
    result["reason_mask"] = reason_mask;
    return result;
}
