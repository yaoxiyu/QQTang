extends QQTIntegrationTest


func test_movement_parity_smoke_contract_exists() -> void:
	var bridge := NativeMovementBridge.new()
	assert_true(bridge != null, "native movement parity harness should be present")
