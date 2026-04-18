extends "res://tests/gut/base/qqt_unit_test.gd"

const BattleSessionBootstrapScript = preload("res://network/session/battle_session_bootstrap.gd")


func test_build_transport_config_uses_client_transport_identity() -> void:
	var config := BattleStartConfig.new()
	config.battle_seed = 42
	config.players = [
		{"peer_id": 2},
		{"peer_id": 3},
	]

	var transport_config := BattleSessionBootstrapScript.build_transport_config(
		BattleSessionBootstrapScript.NETWORK_MODE_CLIENT,
		config,
		2,
		"127.0.0.1",
		9010,
		4
	)

	assert_false(bool(transport_config.get("is_server", true)), "client transport should not be server")
	assert_eq(int(transport_config.get("local_peer_id", -1)), 0, "client transport should wait for ENet peer id")
	assert_eq(Array(transport_config.get("remote_peer_ids", [1])).size(), 0, "client transport should not predeclare remote peers")


func test_resolve_remote_peer_ids_excludes_local_peer() -> void:
	var config := BattleStartConfig.new()
	config.players = [
		{"peer_id": 1},
		{"peer_id": 2},
		{"peer_id": 3},
	]

	var remote_peer_ids := BattleSessionBootstrapScript.resolve_remote_peer_ids(config, 2)

	assert_eq(remote_peer_ids, [1, 3], "remote peer list should exclude local peer")
