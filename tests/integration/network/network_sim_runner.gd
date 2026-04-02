class_name NetworkSimRunner
extends Node

const FakeTransportScript = preload("res://tests/helpers/fake_transport.gd")
const DualClientRunnerScript = preload("res://tests/integration/network/dual_client_runner.gd")
const BuiltinMapFactoryScript = preload("res://gameplay/simulation/runtime/builtin_map_factory.gd")

var transport = FakeTransportScript.new()
var dual_runner = null


func setup(config: Dictionary = {}) -> void:
	transport.configure(config)
	dual_runner = DualClientRunnerScript.new()
	add_child(dual_runner)
	dual_runner.setup(
		int(config.get("peer_a", 101)),
		int(config.get("peer_b", 202)),
		int(config.get("seed", 1)),
		config.get("map_data", BuiltinMapFactoryScript.build_basic_map())
	)

	for message in dual_runner.consume_server_messages():
		transport.send("server_to_client", message, 0)


func run(input_by_tick: Array[Dictionary], flush_ticks: int = 8) -> Dictionary:
	var current_tick := 0
	for tick_inputs in input_by_tick:
		current_tick += 1
		_send_client_inputs(current_tick, tick_inputs)
		_deliver_client_inputs(current_tick)
		dual_runner.server.tick_once()
		for message in dual_runner.consume_server_messages():
			transport.send("server_to_client", message, current_tick)
		_deliver_server_messages(current_tick)

	_queue_final_checkpoint(current_tick)

	var flush_until := current_tick + flush_ticks
	while current_tick < flush_until and transport.has_pending():
		current_tick += 1
		_deliver_client_inputs(current_tick)
		_deliver_server_messages(current_tick)

	var server_tick: int = int(dual_runner.server.active_match.sim_world.state.match_state.tick)
	var authoritative_snapshot = dual_runner.server.active_match.get_snapshot(server_tick)
	return {
		"server_tick": server_tick,
		"authoritative_snapshot": authoritative_snapshot,
		"authoritative_summary": dual_runner.server.active_match.build_player_position_summary(),
		"client_a_tick": dual_runner.client_a.latest_snapshot_tick,
		"client_b_tick": dual_runner.client_b.latest_snapshot_tick,
		"client_a_players": dual_runner.client_a.latest_player_summary,
		"client_b_players": dual_runner.client_b.latest_player_summary,
		"transport_stats": {
			"delivered": transport.delivered_count,
			"dropped": transport.dropped_count,
			"duplicated": transport.duplicated_count,
			"pending": transport.pending_count()
		}
	}


func _send_client_inputs(current_tick: int, tick_inputs: Dictionary) -> void:
	var peer_a: int = int(dual_runner.client_a.local_peer_id)
	var peer_b: int = int(dual_runner.client_b.local_peer_id)
	var move_a: Vector2i = tick_inputs.get(peer_a, Vector2i.ZERO)
	var move_b: Vector2i = tick_inputs.get(peer_b, Vector2i.ZERO)
	transport.send("client_to_server", dual_runner.client_a.sample_input_for_tick(current_tick, move_a.x, move_a.y), current_tick)
	transport.send("client_to_server", dual_runner.client_b.sample_input_for_tick(current_tick, move_b.x, move_b.y), current_tick)


func _deliver_client_inputs(current_tick: int) -> void:
	for frame in transport.pop_ready("client_to_server", current_tick):
		dual_runner.server.receive_input(frame)


func _deliver_server_messages(current_tick: int) -> void:
	for message in transport.pop_ready("server_to_client", current_tick):
		var msg_type := String(message.get("msg_type", ""))
		match msg_type:
			"INPUT_ACK":
				var peer_id := int(message.get("peer_id", -1))
				var ack_tick := int(message.get("ack_tick", 0))
				if peer_id == dual_runner.client_a.local_peer_id:
					dual_runner.client_a.on_input_ack(ack_tick)
				elif peer_id == dual_runner.client_b.local_peer_id:
					dual_runner.client_b.on_input_ack(ack_tick)
			"STATE_SUMMARY":
				dual_runner.client_a.on_state_summary(message)
				dual_runner.client_b.on_state_summary(message)
			"CHECKPOINT":
				dual_runner.client_a.on_snapshot(message)
				dual_runner.client_b.on_snapshot(message)
			_:
				pass


func _queue_final_checkpoint(current_tick: int) -> void:
	var final_tick: int = int(dual_runner.server.active_match.sim_world.state.match_state.tick)
	var snapshot = dual_runner.server.active_match.get_snapshot(final_tick)
	if snapshot == null:
		return

	var message := {
		"msg_type": "CHECKPOINT",
		"tick": snapshot.tick_id,
		"players": snapshot.players,
		"player_summary": dual_runner.server.active_match.build_player_position_summary(),
		"bubbles": snapshot.bubbles,
		"items": snapshot.items,
		"checksum": snapshot.checksum
	}
	for _i in range(3):
		transport.send("server_to_client", message.duplicate(true), current_tick)
