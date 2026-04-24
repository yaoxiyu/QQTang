class_name SnapshotBuffer
extends RefCounted

const NativeFeatureFlagsScript = preload("res://gameplay/native_bridge/native_feature_flags.gd")
const NativeKernelRuntimeScript = preload("res://gameplay/native_bridge/native_kernel_runtime.gd")
const NativeSnapshotBridgeScript = preload("res://gameplay/native_bridge/native_snapshot_bridge.gd")

var capacity: int = 16
var snapshots: Dictionary = {}
var _native_ring: Object = null
var _use_native_ring: bool = false
var _native_snapshot_bridge: NativeSnapshotBridge = NativeSnapshotBridgeScript.new()
var _native_ring_configured: bool = false


func _init(p_capacity: int = 16) -> void:
	capacity = max(1, p_capacity)
	_refresh_native_mode()


func put(snapshot: WorldSnapshot) -> void:
	if snapshot == null:
		return
	_refresh_native_mode()
	if _use_native_ring:
		_ensure_native_ring_ready()
		if _native_ring != null:
			_native_ring.put_snapshot(snapshot.tick_id, _native_snapshot_bridge.pack_snapshot(snapshot))
			return

	snapshots[snapshot.tick_id] = snapshot.duplicate_deep()

	var min_tick := snapshot.tick_id - capacity + 1
	var to_remove: Array[int] = []
	for tick in snapshots.keys():
		if tick < min_tick:
			to_remove.append(tick)

	for tick in to_remove:
		snapshots.erase(tick)


func get_snapshot(tick_id: int) -> WorldSnapshot:
	_refresh_native_mode()
	if _use_native_ring:
		_ensure_native_ring_ready()
		if _native_ring != null and _native_ring.has_snapshot(tick_id):
			return _native_snapshot_bridge.unpack_snapshot(_native_ring.get_snapshot(tick_id))

	var snapshot: WorldSnapshot = snapshots.get(tick_id, null)
	if snapshot != null:
		return snapshot.duplicate_deep()
	if _native_ring != null and _native_ring.has_snapshot(tick_id):
		return _native_snapshot_bridge.unpack_snapshot(_native_ring.get_snapshot(tick_id))
	return null


func has_snapshot(tick_id: int) -> bool:
	_refresh_native_mode()
	if _use_native_ring:
		_ensure_native_ring_ready()
		if _native_ring != null and _native_ring.has_snapshot(tick_id):
			return true
	return snapshots.has(tick_id) or (_native_ring != null and _native_ring.has_snapshot(tick_id))


func get_packed_snapshot(tick_id: int) -> PackedByteArray:
	_refresh_native_mode()
	if _use_native_ring:
		_ensure_native_ring_ready()
		if _native_ring != null and _native_ring.has_snapshot(tick_id):
			return _native_ring.get_snapshot(tick_id)

	var snapshot: WorldSnapshot = snapshots.get(tick_id, null)
	if snapshot != null:
		return _native_snapshot_bridge.pack_snapshot(snapshot)
	if _native_ring != null and _native_ring.has_snapshot(tick_id):
		return _native_ring.get_snapshot(tick_id)
	return PackedByteArray()


func clear() -> void:
	snapshots.clear()
	if _native_ring != null:
		_native_ring.clear()
		_native_ring_configured = false


func _refresh_native_mode() -> void:
	_use_native_ring = (
		NativeFeatureFlagsScript.enable_native_snapshot_ring
		and NativeKernelRuntimeScript.is_available()
		and NativeKernelRuntimeScript.has_snapshot_ring_kernel()
	)
	if NativeFeatureFlagsScript.enable_native_snapshot_ring and not _use_native_ring and NativeFeatureFlagsScript.require_native_kernels:
		push_error("[snapshot_buffer] native snapshot ring is required but unavailable")
	if not _use_native_ring:
		_native_ring = null
		_native_ring_configured = false


func _ensure_native_ring_ready() -> void:
	if not _use_native_ring:
		return
	if _native_ring == null:
		_native_ring = NativeKernelRuntimeScript.get_snapshot_ring_kernel()
		_native_ring_configured = false
	if _native_ring != null and not _native_ring_configured:
		_native_ring.configure(capacity)
		_native_ring_configured = true
