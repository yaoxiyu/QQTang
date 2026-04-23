extends QQTIntegrationTest


func test_rollback_parity_smoke_contract_exists() -> void:
	var rollback_controller := RollbackController.new()
	assert_true(rollback_controller != null, "native rollback parity harness should be present")
