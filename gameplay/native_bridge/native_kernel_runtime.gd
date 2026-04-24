class_name NativeKernelRuntime
extends RefCounted

const LogBattleScript = preload("res://app/logging/log_battle.gd")

const LOG_TAG := "battle.native.runtime"
const CHECKSUM_KERNEL_CLASS := "QQTNativeChecksumBuilder"
const SNAPSHOT_RING_KERNEL_CLASS := "QQTNativeSnapshotRing"
const MOVEMENT_KERNEL_CLASS := "QQTNativeMovementKernel"
const EXPLOSION_KERNEL_CLASS := "QQTNativeExplosionKernel"
const AUTHORITY_BATCH_COALESCER_CLASS := "QQTNativeAuthorityBatchCoalescer"
const INPUT_BUFFER_CLASS := "QQTNativeInputBuffer"
const SNAPSHOT_DIFF_CLASS := "QQTNativeSnapshotDiff"
const ROLLBACK_PLANNER_CLASS := "QQTNativeRollbackPlanner"
const BATTLE_MESSAGE_CODEC_CLASS := "QQTNativeBattleMessageCodec"
const EXPECTED_KERNEL_VERSION := "phase30_kernel_v1"
const EXPECTED_SYNC_KERNEL_VERSION := "phase32_sync_kernel_v1"

static var _availability_checked: bool = false
static var _is_available_cached: bool = false
static var _kernel_version_cached: String = ""
static var _kernel_probe_state: Dictionary = {}
static var _checksum_kernel: Object = null
static var _snapshot_ring_kernel: Object = null
static var _movement_kernel: Object = null
static var _explosion_kernel: Object = null
static var _authority_batch_coalescer_kernel: Object = null
static var _input_buffer_kernel: Object = null
static var _snapshot_diff_kernel: Object = null
static var _rollback_planner_kernel: Object = null
static var _battle_message_codec_kernel: Object = null


static func is_available() -> bool:
	_ensure_runtime_checked()
	return _is_available_cached


static func get_kernel_version() -> String:
	_ensure_runtime_checked()
	return _kernel_version_cached


static func has_checksum_kernel() -> bool:
	return _has_kernel(CHECKSUM_KERNEL_CLASS)


static func has_snapshot_ring_kernel() -> bool:
	return _has_kernel(SNAPSHOT_RING_KERNEL_CLASS)


static func has_movement_kernel() -> bool:
	return _has_kernel(MOVEMENT_KERNEL_CLASS)


static func has_explosion_kernel() -> bool:
	return _has_kernel(EXPLOSION_KERNEL_CLASS)


static func has_authority_batch_coalescer_kernel() -> bool:
	return _has_kernel(AUTHORITY_BATCH_COALESCER_CLASS)


static func has_input_buffer_kernel() -> bool:
	return _has_kernel(INPUT_BUFFER_CLASS)


static func has_snapshot_diff_kernel() -> bool:
	return _has_kernel(SNAPSHOT_DIFF_CLASS)


static func has_rollback_planner_kernel() -> bool:
	return _has_kernel(ROLLBACK_PLANNER_CLASS)


static func has_battle_message_codec_kernel() -> bool:
	return _has_kernel(BATTLE_MESSAGE_CODEC_CLASS)


static func get_checksum_kernel() -> Object:
	return _get_or_create_kernel(CHECKSUM_KERNEL_CLASS, "_checksum_kernel")


static func get_snapshot_ring_kernel() -> Object:
	return _get_or_create_kernel(SNAPSHOT_RING_KERNEL_CLASS, "_snapshot_ring_kernel")


static func get_movement_kernel() -> Object:
	return _get_or_create_kernel(MOVEMENT_KERNEL_CLASS, "_movement_kernel")


static func get_explosion_kernel() -> Object:
	return _get_or_create_kernel(EXPLOSION_KERNEL_CLASS, "_explosion_kernel")


static func get_authority_batch_coalescer_kernel() -> Object:
	return _get_or_create_kernel(AUTHORITY_BATCH_COALESCER_CLASS, "_authority_batch_coalescer_kernel")


static func get_input_buffer_kernel() -> Object:
	return _get_or_create_kernel(INPUT_BUFFER_CLASS, "_input_buffer_kernel")


static func get_snapshot_diff_kernel() -> Object:
	return _get_or_create_kernel(SNAPSHOT_DIFF_CLASS, "_snapshot_diff_kernel")


static func get_rollback_planner_kernel() -> Object:
	return _get_or_create_kernel(ROLLBACK_PLANNER_CLASS, "_rollback_planner_kernel")


static func get_battle_message_codec_kernel() -> Object:
	return _get_or_create_kernel(BATTLE_MESSAGE_CODEC_CLASS, "_battle_message_codec_kernel")


static func _ensure_runtime_checked() -> void:
	if _availability_checked:
		return
	_availability_checked = true
	_is_available_cached = _probe_availability()


static func _probe_availability() -> bool:
	var checksum_kernel := _instantiate_kernel(CHECKSUM_KERNEL_CLASS)
	if checksum_kernel == null:
		return false
	if not checksum_kernel.has_method("get_kernel_version"):
		LogBattleScript.warn(
			"[native_kernel_runtime] checksum kernel missing get_kernel_version, fallback to GDScript",
			"",
			0,
			LOG_TAG
		)
		return false
	_kernel_version_cached = String(checksum_kernel.call("get_kernel_version"))
	if _kernel_version_cached != EXPECTED_KERNEL_VERSION:
		LogBattleScript.warn(
			"[native_kernel_runtime] kernel version mismatch expected=%s actual=%s" % [
				EXPECTED_KERNEL_VERSION,
				_kernel_version_cached,
			],
			"",
			0,
			LOG_TAG
		)
		return false
	_checksum_kernel = checksum_kernel
	_kernel_probe_state[CHECKSUM_KERNEL_CLASS] = true
	_kernel_probe_state[SNAPSHOT_RING_KERNEL_CLASS] = _probe_kernel_class_version(SNAPSHOT_RING_KERNEL_CLASS)
	_kernel_probe_state[MOVEMENT_KERNEL_CLASS] = _probe_kernel_class_version(MOVEMENT_KERNEL_CLASS)
	_kernel_probe_state[EXPLOSION_KERNEL_CLASS] = _probe_kernel_class_version(EXPLOSION_KERNEL_CLASS)
	_kernel_probe_state[AUTHORITY_BATCH_COALESCER_CLASS] = _probe_sync_kernel_class_version(AUTHORITY_BATCH_COALESCER_CLASS)
	_kernel_probe_state[INPUT_BUFFER_CLASS] = _probe_sync_kernel_class_version(INPUT_BUFFER_CLASS)
	_kernel_probe_state[SNAPSHOT_DIFF_CLASS] = _probe_sync_kernel_class_version(SNAPSHOT_DIFF_CLASS)
	_kernel_probe_state[ROLLBACK_PLANNER_CLASS] = _probe_sync_kernel_class_version(ROLLBACK_PLANNER_CLASS)
	_kernel_probe_state[BATTLE_MESSAGE_CODEC_CLASS] = _probe_sync_kernel_class_version(BATTLE_MESSAGE_CODEC_CLASS)
	_log_native_loaded()
	return true


static func _log_native_loaded() -> void:
	var message := "[native_kernel_runtime] qqt_native loaded version=%s checksum=%s snapshot_ring=%s movement=%s explosion=%s authority_batch=%s input_buffer=%s snapshot_diff=%s rollback_planner=%s battle_codec=%s" % [
		_kernel_version_cached,
		str(_kernel_probe_state.get(CHECKSUM_KERNEL_CLASS, false)),
		str(_kernel_probe_state.get(SNAPSHOT_RING_KERNEL_CLASS, false)),
		str(_kernel_probe_state.get(MOVEMENT_KERNEL_CLASS, false)),
		str(_kernel_probe_state.get(EXPLOSION_KERNEL_CLASS, false)),
		str(_kernel_probe_state.get(AUTHORITY_BATCH_COALESCER_CLASS, false)),
		str(_kernel_probe_state.get(INPUT_BUFFER_CLASS, false)),
		str(_kernel_probe_state.get(SNAPSHOT_DIFF_CLASS, false)),
		str(_kernel_probe_state.get(ROLLBACK_PLANNER_CLASS, false)),
		str(_kernel_probe_state.get(BATTLE_MESSAGE_CODEC_CLASS, false)),
	]
	if LogManager.is_initialized():
		LogBattleScript.info(message, "", 0, LOG_TAG)
	else:
		print(message)


static func _probe_kernel_class_version(p_class_name: String) -> bool:
	var kernel := _instantiate_kernel(p_class_name)
	if kernel == null:
		return false
	if not kernel.has_method("get_kernel_version"):
		LogBattleScript.warn(
			"[native_kernel_runtime] kernel missing get_kernel_version, disabling class=%s" % p_class_name,
			"",
			0,
			LOG_TAG
		)
		return false
	var actual_version := String(kernel.call("get_kernel_version"))
	if actual_version != EXPECTED_KERNEL_VERSION:
		LogBattleScript.warn(
			"[native_kernel_runtime] kernel version mismatch class=%s expected=%s actual=%s" % [
				p_class_name,
				EXPECTED_KERNEL_VERSION,
				actual_version,
			],
			"",
			0,
			LOG_TAG
		)
		return false
	return true


static func _probe_sync_kernel_class_version(p_class_name: String) -> bool:
	var kernel := _instantiate_kernel(p_class_name)
	if kernel == null:
		return false
	if not kernel.has_method("get_kernel_version"):
		LogBattleScript.warn(
			"[native_kernel_runtime] sync kernel missing get_kernel_version, disabling class=%s" % p_class_name,
			"",
			0,
			LOG_TAG
		)
		return false
	var actual_version := String(kernel.call("get_kernel_version"))
	if actual_version != EXPECTED_SYNC_KERNEL_VERSION:
		LogBattleScript.warn(
			"[native_kernel_runtime] sync kernel version mismatch class=%s expected=%s actual=%s" % [
				p_class_name,
				EXPECTED_SYNC_KERNEL_VERSION,
				actual_version,
			],
			"",
			0,
			LOG_TAG
		)
		return false
	return true


static func _get_or_create_kernel(p_class_name: String, cache_name: String) -> Object:
	_ensure_runtime_checked()
	if not _is_available_cached or not _has_kernel(p_class_name):
		return null
	var cached := _get_cached_kernel(cache_name)
	if cached != null:
		return cached
	var instance: Object = _instantiate_kernel(p_class_name)
	if instance == null:
		LogBattleScript.warn(
			"[native_kernel_runtime] kernel instantiate failed, fallback to GDScript class=%s" % p_class_name,
			"",
			0,
			LOG_TAG
		)
		return null
	_set_cached_kernel(cache_name, instance)
	return instance


static func _instantiate_kernel(p_class_name: String) -> Object:
	if not ClassDB.can_instantiate(p_class_name):
		LogBattleScript.warn(
			"[native_kernel_runtime] native class unavailable, fallback to GDScript class=%s" % p_class_name,
			"",
			0,
			LOG_TAG
		)
		return null
	var instance: Object = ClassDB.instantiate(p_class_name)
	if instance == null:
		LogBattleScript.warn(
			"[native_kernel_runtime] native class instantiate returned null class=%s" % p_class_name,
			"",
			0,
			LOG_TAG
	)
	return instance


static func _has_kernel(p_class_name: String) -> bool:
	_ensure_runtime_checked()
	if not _is_available_cached:
		return false
	return bool(_kernel_probe_state.get(p_class_name, false))


static func _get_cached_kernel(cache_name: String) -> Object:
	match cache_name:
		"_checksum_kernel":
			return _checksum_kernel
		"_snapshot_ring_kernel":
			return _snapshot_ring_kernel
		"_movement_kernel":
			return _movement_kernel
		"_explosion_kernel":
			return _explosion_kernel
		"_authority_batch_coalescer_kernel":
			return _authority_batch_coalescer_kernel
		"_input_buffer_kernel":
			return _input_buffer_kernel
		"_snapshot_diff_kernel":
			return _snapshot_diff_kernel
		"_rollback_planner_kernel":
			return _rollback_planner_kernel
		"_battle_message_codec_kernel":
			return _battle_message_codec_kernel
		_:
			return null


static func _set_cached_kernel(cache_name: String, instance: Object) -> void:
	match cache_name:
		"_checksum_kernel":
			_checksum_kernel = instance
		"_snapshot_ring_kernel":
			_snapshot_ring_kernel = instance
		"_movement_kernel":
			_movement_kernel = instance
		"_explosion_kernel":
			_explosion_kernel = instance
		"_authority_batch_coalescer_kernel":
			_authority_batch_coalescer_kernel = instance
		"_input_buffer_kernel":
			_input_buffer_kernel = instance
		"_snapshot_diff_kernel":
			_snapshot_diff_kernel = instance
		"_rollback_planner_kernel":
			_rollback_planner_kernel = instance
		"_battle_message_codec_kernel":
			_battle_message_codec_kernel = instance
