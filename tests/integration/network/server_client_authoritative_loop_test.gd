extends "res://tests/gut/base/qqt_integration_test.gd"


func test_main() -> void:
	var server := ServerSession.new()
	var client_a := ClientSession.new()
	var client_b := ClientSession.new()
	add_child(server)
	add_child(client_a)
	add_child(client_b)

	client_a.configure(101)
	client_b.configure(202)

	server.create_room("sync_test_room", "basic_map", "default")
	server.add_peer(101)
	server.add_peer(202)
	server.set_peer_ready(101, true)
	server.set_peer_ready(202, true)

	var started := server.start_match(SimConfig.new(), {"grid": BuiltinMapFactory.build_basic_map()}, 9001, 0)
	_assert(started, "server should start match when all peers are ready")
	_assert(server.active_match != null, "active_match should be created")

	var tick_scripts := [
		{101: Vector2i(1, 0), 202: Vector2i(-1, 0)},
		{101: Vector2i(0, 0), 202: Vector2i(0, 1)},
		{101: Vector2i(1, 0), 202: Vector2i(0, 0)}
	]

	for tick_index in range(tick_scripts.size()):
		var tick_id := tick_index + 1
		var inputs: Dictionary = tick_scripts[tick_index]
		client_a.send_input(client_a.sample_input_for_tick(tick_id, inputs[101].x, inputs[101].y))
		client_b.send_input(client_b.sample_input_for_tick(tick_id, inputs[202].x, inputs[202].y))

		for frame in client_a.flush_outgoing_inputs():
			server.receive_input(frame)
		for frame in client_b.flush_outgoing_inputs():
			server.receive_input(frame)

		server.tick_once()
		_apply_server_messages(server, client_a, client_b)

		_assert(client_a.last_confirmed_tick == tick_id, "client A ack should advance with server tick")
		_assert(client_b.last_confirmed_tick == tick_id, "client B ack should advance with server tick")
		_assert(client_a.latest_snapshot_tick == tick_id, "client A summary tick should match server tick")
		_assert(client_b.latest_snapshot_tick == tick_id, "client B summary tick should match server tick")

	var authoritative_summary := server.active_match.build_player_position_summary()
	_assert(client_a.latest_player_summary == authoritative_summary, "client A summary should match authoritative summary")
	_assert(client_b.latest_player_summary == authoritative_summary, "client B summary should match authoritative summary")

	var checksum := server.active_match.compute_checksum(server.active_match.sim_world.state.match_state.tick)
	_assert(checksum != 0, "authoritative checksum should be generated after sync ticks")

	server.free()
	client_a.free()
	client_b.free()



func _apply_server_messages(server: ServerSession, client_a: ClientSession, client_b: ClientSession) -> void:
	for message in server.poll_messages():
		var message_type := String(message.get("message_type", ""))
		match message_type:
			"INPUT_ACK":
				var peer_id := int(message.get("peer_id", -1))
				var ack_tick := int(message.get("ack_tick", 0))
				if peer_id == client_a.local_peer_id:
					client_a.on_input_ack(ack_tick)
				elif peer_id == client_b.local_peer_id:
					client_b.on_input_ack(ack_tick)
			"STATE_SUMMARY":
				client_a.on_state_summary(message)
				client_b.on_state_summary(message)
			"CHECKPOINT":
				client_a.on_snapshot(message)
				client_b.on_snapshot(message)
			_:
				pass


func _assert(condition: bool, message: String) -> void:
	assert_true(condition, message)

