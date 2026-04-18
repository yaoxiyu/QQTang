extends "res://tests/gut/base/qqt_unit_test.gd"

const ClientRuntimeResumeCoordinatorScript = preload("res://network/session/runtime/client_runtime_resume_coordinator.gd")


func test_sideband_gate_accepts_monotonic_ticks_only_when_suppressed() -> void:
	var coordinator := ClientRuntimeResumeCoordinatorScript.new()
	var world := SimWorld.new()

	assert_true(coordinator.should_apply_authority_sideband(world, true, 10), "first sideband tick should apply")
	coordinator.note_applied_authority_sideband(10)
	assert_false(coordinator.should_apply_authority_sideband(world, true, 9), "older sideband tick should be skipped")
	assert_true(coordinator.should_apply_authority_sideband(world, true, 11), "newer sideband tick should apply")
	assert_true(coordinator.should_apply_authority_sideband(world, false, 9), "non-suppressed mode should accept any tick")


func test_resolve_place_action_ignores_unrequested_place() -> void:
	var coordinator := ClientRuntimeResumeCoordinatorScript.new()

	assert_false(coordinator.resolve_local_place_action(false, 1, null), "unrequested place should stay false")
