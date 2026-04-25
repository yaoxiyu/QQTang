extends "res://tests/gut/base/qqt_unit_test.gd"

const PredictionControllerScript = preload("res://gameplay/network/prediction/prediction_controller.gd")


func test_prediction_advances_idle_ticks_without_local_input() -> void:
	var predicted_world := _build_world(9090)
	var snapshot_service := SnapshotService.new()
	var local_input_buffer := InputRingBuffer.new(16)
	var controller: PredictionController = PredictionControllerScript.new()
	add_child(controller)
	controller.configure(predicted_world, snapshot_service, local_input_buffer, 0)

	controller.predict_to_tick(10)

	assert_eq(controller.predicted_until_tick, 10)
	for tick_id in range(1, 11):
		assert_not_null(controller.snapshot_buffer.get_snapshot(tick_id), "idle prediction should record tick %d" % tick_id)
	assert_eq(local_input_buffer.frames.size(), 0)

	controller.dispose()
	controller.free()
	predicted_world.dispose()


func _build_world(seed: int) -> SimWorld:
	var world := SimWorld.new()
	world.rng = SimRng.new(seed)
	world.bootstrap(SimConfig.new(), {"grid": BuiltinMapFactory.build_basic_map()})
	return world
