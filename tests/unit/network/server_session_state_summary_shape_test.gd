extends "res://tests/gut/base/qqt_unit_test.gd"

const ServerSessionScript = preload("res://network/session/runtime/server_session.gd")
const TransportMessageTypesScript = preload("res://network/transport/transport_message_types.gd")


func test_state_summary_is_lightweight_and_checkpoint_keeps_full_state() -> void:
	var session: ServerSession = ServerSessionScript.new()
	add_child(session)
	session.create_room("server_session_shape_room")
	for peer_id in [1, 2]:
		session.add_peer(peer_id)
		session.set_peer_ready(peer_id, true)
	assert_true(session.start_match(SimConfig.new(), {"grid": BuiltinMapFactory.build_basic_map()}, 123, 0))
	session.poll_messages()

	for _i in range(5):
		session.tick_once()
	var messages := session.poll_messages()
	var summary := _latest_message(messages, TransportMessageTypesScript.STATE_SUMMARY)
	var delta := _latest_message(messages, TransportMessageTypesScript.STATE_DELTA)
	var checkpoint := _latest_message(messages, TransportMessageTypesScript.CHECKPOINT)

	assert_false(summary.is_empty())
	assert_false(summary.has("walls"))
	assert_true(summary.has("tick"))
	assert_true(summary.has("player_summary"))
	assert_false(summary.has("bubbles"))
	assert_false(summary.has("items"))
	assert_false(summary.has("match_state"))
	assert_true(summary.has("match_phase"))
	assert_true(summary.has("events"))
	assert_true(summary.has("checksum"))

	if not delta.is_empty():
		assert_true(delta.has("changed_bubbles"))
		assert_true(delta.has("removed_bubble_ids"))
		assert_true(delta.has("changed_items"))
		assert_true(delta.has("removed_item_ids"))

	assert_false(checkpoint.is_empty())
	assert_true(checkpoint.has("walls"))
	assert_true(checkpoint.has("mode_state"))
	assert_true(checkpoint.has("rng_state"))

	session.queue_free()


func _latest_message(messages: Array[Dictionary], message_type: String) -> Dictionary:
	var result: Dictionary = {}
	for message in messages:
		if String(message.get("message_type", message.get("msg_type", ""))) == message_type:
			result = message
	return result
