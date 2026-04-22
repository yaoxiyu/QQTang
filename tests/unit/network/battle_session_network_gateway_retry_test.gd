extends "res://tests/gut/base/qqt_unit_test.gd"

const BattleSessionAdapterScript = preload("res://network/session/battle_session_adapter.gd")


func test_dedicated_client_connect_timeout_schedules_retry_without_surface_error() -> void:
	var adapter = qqt_add_child(BattleSessionAdapterScript.new())
	var gateway = _prepare_dedicated_client_gateway(adapter)
	var surfaced_errors: Array[Dictionary] = []
	adapter.network_transport_error.connect(func(code: int, message: String) -> void:
		surfaced_errors.append({
			"code": code,
			"message": message,
		})
	)
	gateway.set("_dedicated_client_connect_retry_delays_sec", [0.5])
	gateway.call("_begin_dedicated_client_connect_retry_tracking", "127.0.0.1", 19010, 5.0)

	gateway.call("_on_transport_error", ERR_TIMEOUT, "Connection timed out")

	assert_eq(surfaced_errors.size(), 0, "opening timeout should be absorbed while retry is available")
	assert_eq(int(gateway.get("_dedicated_client_connect_retry_attempt")), 1, "retry attempt should advance")
	assert_gt(int(gateway.get("_dedicated_client_connect_retry_deadline_msec")), 0, "retry should schedule a restart deadline")


func test_dedicated_client_connect_timeout_surfaces_after_retry_exhausted() -> void:
	var adapter = qqt_add_child(BattleSessionAdapterScript.new())
	var gateway = _prepare_dedicated_client_gateway(adapter)
	var surfaced_errors: Array[Dictionary] = []
	adapter.network_transport_error.connect(func(code: int, message: String) -> void:
		surfaced_errors.append({
			"code": code,
			"message": message,
		})
	)
	gateway.call("_begin_dedicated_client_connect_retry_tracking", "127.0.0.1", 19010, 5.0)
	var retry_delays: Array = gateway.get("_dedicated_client_connect_retry_delays_sec")
	gateway.set("_dedicated_client_connect_retry_attempt", retry_delays.size())

	gateway.call("_on_transport_error", ERR_TIMEOUT, "Connection timed out")

	assert_eq(surfaced_errors.size(), 1, "exhausted retry budget should surface transport error")
	assert_eq(int(surfaced_errors[0].get("code", OK)), ERR_TIMEOUT, "surfaced code should preserve transport code")


func _prepare_dedicated_client_gateway(adapter: Node):
	adapter.call("_ensure_network_gateway")
	var config := BattleStartConfig.new()
	config.session_mode = "network_client"
	config.topology = "dedicated_server"
	config.authority_host = "127.0.0.1"
	config.authority_port = 19010
	config.match_id = "match_retry"
	config.battle_id = "battle_retry"
	adapter.setup_from_start_config(config)
	adapter.network_mode = adapter.BattleNetworkMode.CLIENT
	return adapter.get("_network_gateway")
