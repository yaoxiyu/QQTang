class_name NativeSnapshotBridge
extends RefCounted

const LogBattleScript = preload("res://app/logging/log_battle.gd")
const NativePackedStateCodecBridgeScript = preload("res://gameplay/native_bridge/native_packed_state_codec_bridge.gd")

const LOG_TAG := "battle.native.snapshot.bridge"

var _codec: NativePackedStateCodecBridge = NativePackedStateCodecBridgeScript.new()


func pack_snapshot(snapshot: WorldSnapshot) -> PackedByteArray:
	if snapshot == null:
		return PackedByteArray()
	return _codec.encode_snapshot_payload(snapshot)


func unpack_snapshot(snapshot_bytes: PackedByteArray) -> WorldSnapshot:
	if snapshot_bytes.is_empty():
		return null
	var snapshot := _codec.decode_snapshot_payload(snapshot_bytes)
	if snapshot == null:
		LogBattleScript.warn(
			"[native_snapshot_bridge] unpack snapshot failed, returning null",
			"",
			0,
			LOG_TAG
		)
	return snapshot
