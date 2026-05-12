## Aggregates rollback diagnostics (probe / plan / corrected) and emits a
## summary line on a fixed interval so the WARN/INFO channel does not get
## flooded by per-tick detail traces. The original detail lines are still
## emitted at DEBUG level for ad-hoc forensic work.
class_name RollbackTelemetry
extends RefCounted

const LogSyncScript = preload("res://app/logging/log_sync.gd")
const TRACE_TAG := "sync.trace"
const SUMMARY_INTERVAL_MSEC := 5000

static var _shared_instance = null


static func shared():
	if _shared_instance == null:
		_shared_instance = load("res://network/session/runtime/rollback_telemetry.gd").new()
	return _shared_instance


static func reset_shared() -> void:
	_shared_instance = null

var _probe_count: int = 0
var _plan_count: int = 0
var _corrected_count: int = 0
var _correction_units_sum: int = 0
var _correction_units_max: int = 0
var _replay_ticks_sum: int = 0
var _replay_ticks_max: int = 0
var _forced_resync_count: int = 0
var _reason_counts: Dictionary = {}
var _last_summary_msec: int = 0


func record_probe(reasons: Array, _predicted_until: int, _ack_tick: int) -> void:
	_probe_count += 1
	for reason in reasons:
		var key := String(reason)
		_reason_counts[key] = int(_reason_counts.get(key, 0)) + 1


func record_plan(replay_ticks: int, force_resync: bool) -> void:
	_plan_count += 1
	var clamped: int = max(0, replay_ticks)
	_replay_ticks_sum += clamped
	if clamped > _replay_ticks_max:
		_replay_ticks_max = clamped
	if force_resync:
		_forced_resync_count += 1


func record_correction(from_pos: Vector2i, to_pos: Vector2i) -> void:
	_corrected_count += 1
	var dx: int = int(to_pos.x) - int(from_pos.x)
	var dy: int = int(to_pos.y) - int(from_pos.y)
	var mag: int = int(sqrt(float(dx * dx + dy * dy)))
	_correction_units_sum += mag
	if mag > _correction_units_max:
		_correction_units_max = mag


func flush_if_due() -> void:
	if _probe_count == 0 and _plan_count == 0 and _corrected_count == 0:
		return
	var now := Time.get_ticks_msec()
	if _last_summary_msec == 0:
		_last_summary_msec = now
		return
	if now - _last_summary_msec < SUMMARY_INTERVAL_MSEC:
		return
	var window_msec: int = max(1, now - _last_summary_msec)
	var avg_replay: int = int(_replay_ticks_sum / int(max(1, _plan_count)))
	var avg_correction: int = int(_correction_units_sum / int(max(1, _corrected_count)))
	LogSyncScript.info(
		"rollback_summary window_msec=%d probes=%d plans=%d corrections=%d forced_resyncs=%d replay_avg=%d replay_max=%d correction_units_avg=%d correction_units_max=%d reasons=%s" % [
			window_msec,
			_probe_count,
			_plan_count,
			_corrected_count,
			_forced_resync_count,
			avg_replay,
			_replay_ticks_max,
			avg_correction,
			_correction_units_max,
			_format_reason_counts(),
		],
		"",
		0,
		"%s sync.rollback.summary" % TRACE_TAG
	)
	_probe_count = 0
	_plan_count = 0
	_corrected_count = 0
	_correction_units_sum = 0
	_correction_units_max = 0
	_replay_ticks_sum = 0
	_replay_ticks_max = 0
	_forced_resync_count = 0
	_reason_counts.clear()
	_last_summary_msec = now


func _format_reason_counts() -> String:
	if _reason_counts.is_empty():
		return "{}"
	var parts: Array[String] = []
	for key in _reason_counts.keys():
		parts.append("%s=%d" % [String(key), int(_reason_counts[key])])
	parts.sort()
	return "{" + ",".join(parts) + "}"
