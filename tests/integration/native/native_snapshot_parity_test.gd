extends QQTIntegrationTest


func test_snapshot_parity_smoke_contract_exists() -> void:
	var bridge := NativeSnapshotBridge.new()
	var snapshot := WorldSnapshot.new()
	snapshot.tick_id = 1
	snapshot.players = [{"entity_id": 1, "cell_x": 1, "cell_y": 1}]

	var unpacked := bridge.unpack_snapshot(bridge.pack_snapshot(snapshot))
	assert_true(unpacked != null, "native snapshot parity harness should roundtrip baseline snapshot")
