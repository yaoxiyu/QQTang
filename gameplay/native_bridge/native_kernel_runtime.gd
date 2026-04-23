class_name NativeKernelRuntime
extends RefCounted

const LogBattleScript = preload("res://app/logging/log_battle.gd")

const LOG_TAG := "battle.native.runtime"
const CHECKSUM_KERNEL_CLASS := "QQTNativeChecksumBuilder"
const SNAPSHOT_RING_KERNEL_CLASS := "QQTNativeSnapshotRing"
const MOVEMENT_KERNEL_CLASS := "QQTNativeMovementKernel"
const EXPLOSION_KERNEL_CLASS := "QQTNativeExplosionKernel"

static var _availability_checked: bool = false
static var _is_available_cached: bool = false
static var _checksum_kernel: Object = null
static var _snapshot_ring_kernel: Object = null
static var _movement_kernel: Object = null
static var _explosion_kernel: Object = null


static func is_available() -> bool:
	_ensure_runtime_checked()
	return _is_available_cached


static func get_checksum_kernel() -> Object:
	return _get_or_create_kernel(CHECKSUM_KERNEL_CLASS, "_checksum_kernel")


static func get_snapshot_ring_kernel() -> Object:
	return _get_or_create_kernel(SNAPSHOT_RING_KERNEL_CLASS, "_snapshot_ring_kernel")


static func get_movement_kernel() -> Object:
	return _get_or_create_kernel(MOVEMENT_KERNEL_CLASS, "_movement_kernel")


static func get_explosion_kernel() -> Object:
	return _get_or_create_kernel(EXPLOSION_KERNEL_CLASS, "_explosion_kernel")


static func _ensure_runtime_checked() -> void:
	if _availability_checked:
		return
	_availability_checked = true
	_is_available_cached = _probe_availability()


static func _probe_availability() -> bool:
	var checksum_kernel := _instantiate_kernel(CHECKSUM_KERNEL_CLASS)
	if checksum_kernel == null:
		return false
	_checksum_kernel = checksum_kernel
	return true


static func _get_or_create_kernel(p_class_name: String, cache_name: String) -> Object:
	_ensure_runtime_checked()
	if not _is_available_cached:
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
