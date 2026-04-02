extends Node

const NetworkSimRunnerScript = preload("res://tests/integration/network/network_sim_runner.gd")


func _ready() -> void:
	var runner = NetworkSimRunnerScript.new()
	add_child(runner)
	runner.setup({
		"seed": 4242,
		"latency_ticks": 1,
		"jitter_ticks": 1,
		"packet_loss_every": 5,
		"duplicate_every": 3,
		"enable_out_of_order": true
	})

	var peer_a: int = runner.dual_runner.client_a.local_peer_id
	var peer_b: int = runner.dual_runner.client_b.local_peer_id
	var result: Dictionary = runner.run([
		{peer_a: Vector2i(1, 0), peer_b: Vector2i(-1, 0)},
		{peer_a: Vector2i(0, 0), peer_b: Vector2i(0, 1)},
		{peer_a: Vector2i(1, 0), peer_b: Vector2i(0, 0)},
		{peer_a: Vector2i(0, 0), peer_b: Vector2i(0, -1)},
		{peer_a: Vector2i(1, 0), peer_b: Vector2i(0, 0)},
		{peer_a: Vector2i(0, 0), peer_b: Vector2i(0, 0)}
	], 10)

	_assert(result["authoritative_snapshot"] != null, "server should produce an authoritative snapshot")
	_assert(result["transport_stats"]["delivered"] > 0, "transport should deliver some messages")
	_assert(result["transport_stats"]["dropped"] > 0, "transport should exercise packet loss path")
	_assert(result["transport_stats"]["duplicated"] > 0, "transport should exercise duplicate path")
	_assert(result["client_a_tick"] == result["server_tick"], "client A should catch up to authoritative tick after flush")
	_assert(result["client_b_tick"] == result["server_tick"], "client B should catch up to authoritative tick after flush")
	_assert(result["client_a_players"] == result["authoritative_summary"], "client A latest summary should match server summary")
	_assert(result["client_b_players"] == result["authoritative_summary"], "client B latest summary should match server summary")

	runner.free()

	print("test_network_sim_runner: PASS")


func _assert(condition: bool, message: String) -> void:
	if not condition:
		push_error("test_network_sim_runner: FAIL - %s" % message)

