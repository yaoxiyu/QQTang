extends QQTIntegrationTest

const AuthorityBatchCoalescerScript = preload("res://network/session/runtime/authority_batch_coalescer.gd")
const NativeAuthorityBatchBridgeScript = preload("res://gameplay/native_bridge/native_authority_batch_bridge.gd")
const NativeFeatureFlagsScript = preload("res://gameplay/native_bridge/native_feature_flags.gd")
const TransportMessageTypesScript = preload("res://network/transport/transport_message_types.gd")


func test_native_matches_gdscript_authority_batch_baseline() -> void:
	var baseline: RefCounted = AuthorityBatchCoalescerScript.new()
	var native_kernel: Object = ClassDB.instantiate("QQTNativeAuthorityBatchCoalescer")
	var messages := _sample_messages()
	var cursor := {"latest_authoritative_tick": 99, "latest_snapshot_tick": 98}

	var baseline_result: Dictionary = baseline.coalesce_client_authority_batch(messages, cursor)
	var native_result: Dictionary = native_kernel.call("coalesce_client_authority_batch", messages, cursor)

	assert_eq(_normalize(baseline_result, ""), _normalize(native_result, ""))


func test_bridge_shadow_mismatch_count_is_zero() -> void:
	var old_enabled := NativeFeatureFlagsScript.enable_native_authority_batch_coalescer
	var old_shadow := NativeFeatureFlagsScript.enable_native_authority_batch_coalescer_shadow
	var old_execute := NativeFeatureFlagsScript.enable_native_authority_batch_coalescer_execute
	NativeFeatureFlagsScript.enable_native_authority_batch_coalescer = true
	NativeFeatureFlagsScript.enable_native_authority_batch_coalescer_shadow = true
	NativeFeatureFlagsScript.enable_native_authority_batch_coalescer_execute = false

	var bridge: RefCounted = NativeAuthorityBatchBridgeScript.new()
	var batch: Dictionary = bridge.coalesce_client_authority_batch(_sample_messages(), {})

	assert_eq(int(bridge.get_metrics().get("native_shadow_mismatch_count", -1)), 0)
	assert_true(bool(batch["metrics"].get("native_shadow_equal", false)))

	NativeFeatureFlagsScript.enable_native_authority_batch_coalescer = old_enabled
	NativeFeatureFlagsScript.enable_native_authority_batch_coalescer_shadow = old_shadow
	NativeFeatureFlagsScript.enable_native_authority_batch_coalescer_execute = old_execute


func test_bridge_execute_uses_native_when_available() -> void:
	var old_enabled := NativeFeatureFlagsScript.enable_native_authority_batch_coalescer
	var old_shadow := NativeFeatureFlagsScript.enable_native_authority_batch_coalescer_shadow
	var old_execute := NativeFeatureFlagsScript.enable_native_authority_batch_coalescer_execute
	NativeFeatureFlagsScript.enable_native_authority_batch_coalescer = true
	NativeFeatureFlagsScript.enable_native_authority_batch_coalescer_shadow = true
	NativeFeatureFlagsScript.enable_native_authority_batch_coalescer_execute = true

	var bridge: RefCounted = NativeAuthorityBatchBridgeScript.new()
	var batch: Dictionary = bridge.coalesce_client_authority_batch(_sample_messages(), {})

	assert_eq(int(batch["latest_snapshot_message"].get("tick", 0)), 106)
	assert_true(bool(batch["metrics"].get("native_shadow_equal", false)))
	assert_eq(int(batch["metrics"].get("native_shadow_mismatch_count", -1)), 0)

	NativeFeatureFlagsScript.enable_native_authority_batch_coalescer = old_enabled
	NativeFeatureFlagsScript.enable_native_authority_batch_coalescer_shadow = old_shadow
	NativeFeatureFlagsScript.enable_native_authority_batch_coalescer_execute = old_execute


func test_bridge_execute_falls_back_to_baseline_when_native_disabled() -> void:
	var old_enabled := NativeFeatureFlagsScript.enable_native_authority_batch_coalescer
	var old_shadow := NativeFeatureFlagsScript.enable_native_authority_batch_coalescer_shadow
	var old_execute := NativeFeatureFlagsScript.enable_native_authority_batch_coalescer_execute
	NativeFeatureFlagsScript.enable_native_authority_batch_coalescer = false
	NativeFeatureFlagsScript.enable_native_authority_batch_coalescer_shadow = true
	NativeFeatureFlagsScript.enable_native_authority_batch_coalescer_execute = true

	var bridge: RefCounted = NativeAuthorityBatchBridgeScript.new()
	var batch: Dictionary = bridge.coalesce_client_authority_batch(_sample_messages(), {})

	assert_eq(int(batch["latest_snapshot_message"].get("tick", 0)), 106)
	assert_false(bool(batch["metrics"].get("native_shadow_equal", false)))
	assert_eq(int(bridge.get_metrics().get("native_shadow_mismatch_count", -1)), 0)

	NativeFeatureFlagsScript.enable_native_authority_batch_coalescer = old_enabled
	NativeFeatureFlagsScript.enable_native_authority_batch_coalescer_shadow = old_shadow
	NativeFeatureFlagsScript.enable_native_authority_batch_coalescer_execute = old_execute


func _sample_messages() -> Array:
	return [
		{"message_type": TransportMessageTypesScript.INPUT_ACK, "peer_id": 2, "ack_tick": 10},
		{"message_type": TransportMessageTypesScript.INPUT_ACK, "peer_id": 2, "ack_tick": 11},
		{"message_type": TransportMessageTypesScript.STATE_SUMMARY, "tick": 102, "events": [{"tick": 102, "name": "summary"}]},
		{"message_type": TransportMessageTypesScript.CHECKPOINT, "tick": 100, "events": [{"tick": 100, "name": "stale"}]},
		{"message_type": TransportMessageTypesScript.CHECKPOINT, "tick": 105, "events": [{"tick": 105, "name": "checkpoint"}]},
		{"message_type": TransportMessageTypesScript.AUTHORITATIVE_SNAPSHOT, "tick": 106, "events": [{"tick": 106, "name": "snapshot"}]},
		{"message_type": TransportMessageTypesScript.MATCH_FINISHED, "tick": 107, "result": {"finish_reason": "force_end"}},
	]


func _normalize(value: Variant, key_name: String) -> Variant:
	if key_name == "coalesce_usec":
		return 0
	if value is PackedInt32Array:
		var packed: PackedInt32Array = value
		var array_result: Array = []
		for item in packed:
			array_result.append(int(item))
		return array_result
	if value is Array:
		var normalized_array: Array = []
		for item in value:
			normalized_array.append(_normalize(item, ""))
		return normalized_array
	if value is Dictionary:
		var dict: Dictionary = value
		var keys: Array = dict.keys()
		keys.sort()
		var normalized_dict: Array = []
		for key in keys:
			normalized_dict.append([String(key), _normalize(dict[key], String(key))])
		return normalized_dict
	return value
