extends "res://tests/gut/base/qqt_unit_test.gd"

const ClientRuntimeMetricsCollectorScript = preload("res://network/session/runtime/client_runtime_metrics_collector.gd")

class MetricsTransport:
	extends RefCounted

	func get_debug_stats() -> Dictionary:
		return {
			"enqueued": 1,
			"delivered": 0,
			"dropped": 0,
		}

	func get_pending_message_count() -> int:
		return 4

func test_transport_stats_include_pending_count() -> void:
	var collector := ClientRuntimeMetricsCollectorScript.new()
	var transport := MetricsTransport.new()

	var stats : Dictionary = collector.get_transport_stats(transport)

	assert_eq(int(stats.get("enqueued", 0)), 1, "stats should keep enqueued count")
	assert_eq(int(stats.get("pending", 0)), 4, "stats should include pending count")


func test_null_transport_has_stable_defaults() -> void:
	var collector := ClientRuntimeMetricsCollectorScript.new()

	assert_eq(collector.get_transport_stats(null), {"enqueued": 0, "delivered": 0, "dropped": 0, "pending": 0}, "null transport stats should be stable")
	assert_eq(collector.get_network_profile_summary(null), "0ms / 0%", "null network profile should be stable")
	assert_eq(collector.capture_transport_profile(null), {}, "null debug profile should be empty")
