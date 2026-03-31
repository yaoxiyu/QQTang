class_name BattleRuntimeMetricsBuilder
extends RefCounted


func build(base_metrics: Dictionary, transport_stats: Dictionary) -> Dictionary:
	var metrics := base_metrics.duplicate(true)
	metrics["delivered_messages"] = int(transport_stats.get("delivered", 0))
	metrics["dropped_messages"] = int(transport_stats.get("dropped", 0))
	metrics["pending_server_messages"] = int(transport_stats.get("pending", 0))
	return metrics
