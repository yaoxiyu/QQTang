class_name BattleContext
extends RefCounted

# Runtime-only assembly context for Phase3 battle flow.
# This object is not a serializable config payload.
var battle_start_config: BattleStartConfig = null
var sim_world: SimWorld = null
var tick_runner: TickRunner = null
var client_session: ClientSession = null
var server_session: ServerSession = null
var prediction_controller: PredictionController = null
var rollback_controller: RollbackController = null
var visual_sync_controller: VisualSyncController = null


func clear_runtime_refs() -> void:
	sim_world = null
	tick_runner = null
	client_session = null
	server_session = null
	prediction_controller = null
	rollback_controller = null
	visual_sync_controller = null


func has_runtime() -> bool:
	return sim_world != null or tick_runner != null
