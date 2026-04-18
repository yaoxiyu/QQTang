extends RefCounted

const ItemSpawnSystemScript = preload("res://gameplay/simulation/systems/item_spawn_system.gd")
const BattleRuntimeMetricsBuilderScript = preload("res://network/session/runtime/battle_runtime_metrics_builder.gd")

var _runtime_metrics_builder: BattleRuntimeMetricsBuilder = BattleRuntimeMetricsBuilderScript.new()


func cycle_latency_profile(transport: Node) -> int:
	if transport != null:
		return transport.cycle_latency_profile()
	return 0


func cycle_loss_profile(transport: Node) -> int:
	if transport != null:
		return transport.cycle_loss_profile()
	return 0


func get_latency_profile_ms(transport: Node) -> int:
	if transport != null:
		return transport.get_latency_profile_ms()
	return 0


func get_packet_loss_percent(transport: Node) -> int:
	if transport != null:
		return transport.get_packet_loss_percent()
	return 0


func get_network_profile_summary(transport: Node) -> String:
	if transport != null:
		return transport.get_network_profile_summary()
	return "0ms / 0%"


func capture_transport_profile(transport: Node) -> Dictionary:
	if transport != null and transport.has_method("export_debug_profile"):
		return transport.call("export_debug_profile")
	return {}


func build_runtime_metrics(
	lifecycle_state: int,
	lifecycle_state_name: String,
	battle_active: bool,
	shutdown_complete: bool,
	current_context: BattleContext,
	client_session: ClientSession,
	prediction_controller: PredictionController,
	transport: Node,
	prediction_debugger: PredictionDivergenceDebugger,
	correction_count: int,
	last_correction_summary: String,
	last_resync_tick: int,
	remote_debug_inputs: bool
) -> Dictionary:
	var authoritative_tick: int = current_context.sim_world.state.match_state.tick if current_context != null and current_context.sim_world != null else 0
	var snapshot_tick: int = client_session.latest_snapshot_tick if client_session != null else authoritative_tick
	var metrics := {
		"lifecycle_state": lifecycle_state,
		"lifecycle_state_name": lifecycle_state_name,
		"battle_active": battle_active,
		"shutdown_complete": shutdown_complete,
		"latency_ms": get_latency_profile_ms(transport),
		"packet_loss_percent": get_packet_loss_percent(transport),
		"ack_tick": client_session.last_confirmed_tick if client_session != null else 0,
		"rollback_count": current_context.rollback_controller.rollback_count if current_context != null and current_context.rollback_controller != null else 0,
		"last_rollback_tick": current_context.rollback_controller.last_rollback_from_tick if current_context != null and current_context.rollback_controller != null else -1,
		"resync_count": current_context.rollback_controller.force_resync_count if current_context != null and current_context.rollback_controller != null else 0,
		"predicted_tick": prediction_controller.predicted_until_tick if prediction_controller != null else authoritative_tick,
		"authoritative_tick": prediction_controller.authoritative_tick if prediction_controller != null else authoritative_tick,
		"snapshot_tick": snapshot_tick,
		"prediction_enabled": prediction_controller != null,
		"network_profile": get_network_profile_summary(transport),
		"force_divergence_armed": prediction_debugger.is_armed() if prediction_debugger != null else false,
		"correction_count": correction_count,
		"last_correction": last_correction_summary,
		"last_resync_tick": last_resync_tick,
		"drop_rate_percent": ItemSpawnSystemScript.get_debug_drop_rate_percent(),
		"remote_debug_inputs": remote_debug_inputs,
	}
	return _runtime_metrics_builder.build(metrics, get_transport_stats(transport))


func get_transport_stats(transport: Object) -> Dictionary:
	if transport == null:
		return {
			"enqueued": 0,
			"delivered": 0,
			"dropped": 0,
			"pending": 0,
		}
	var stats : Dictionary = transport.get_debug_stats()
	if transport.has_method("get_pending_message_count"):
		stats["pending"] = int(transport.call("get_pending_message_count"))
	else:
		stats["pending"] = 0
	return stats
