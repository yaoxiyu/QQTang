extends "res://tests/gut/base/qqt_unit_test.gd"

const ClientRuntimeSnapshotApplierScript = preload("res://network/session/runtime/client_runtime_snapshot_applier.gd")


func test_snapshot_from_message_normalizes_integer_floats() -> void:
	var snapshot := ClientRuntimeSnapshotApplierScript.snapshot_from_message({
		"tick": 12.0,
		"players": [
			{"entity_id": 1.0, "cell": {"x": 2.0, "y": 3.5}},
		],
		"match_state": {
			"remaining_ticks": 90.0,
		},
	})

	assert_eq(snapshot.tick_id, 12, "snapshot tick should be coerced")
	assert_eq(snapshot.players[0]["entity_id"], 1, "integer-like floats should normalize")
	assert_eq(snapshot.players[0]["cell"]["x"], 2, "nested integer-like floats should normalize")
	assert_eq(snapshot.players[0]["cell"]["y"], 3.5, "non-integer floats should stay float")
	assert_eq(snapshot.match_state["remaining_ticks"], 90, "match state should normalize")


func test_decode_events_denormalizes_vector_payload() -> void:
	var events := ClientRuntimeSnapshotApplierScript.decode_events([
		{
			"tick": 7,
			"event_type": SimEvent.EventType.BUBBLE_PLACED,
			"payload": {
				"cell": {
					"__type": "Vector2i",
					"x": 3,
					"y": 4,
				},
			},
		},
	])

	assert_eq(events.size(), 1, "event should decode")
	assert_eq(events[0].payload["cell"], Vector2i(3, 4), "tagged Vector2i payload should denormalize")
