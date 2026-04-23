extends QQTIntegrationTest


func test_explosion_parity_smoke_contract_exists() -> void:
	var bridge := NativeExplosionBridge.new()
	assert_true(bridge != null, "native explosion parity harness should be present")
