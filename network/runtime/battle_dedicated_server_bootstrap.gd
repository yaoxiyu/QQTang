extends Node

const OrchestratorScript = preload("res://network/runtime/ds/battle_dedicated_server_orchestrator.gd")

@export var listen_port: int = 9000
@export var max_clients: int = 8
@export var authority_host: String = "127.0.0.1"
@export var battle_ticket_secret: String = "dev_battle_ticket_secret"
@export var resume_window_sec: float = 20.0

var _orchestrator: Node = null


func _ready() -> void:
	_orchestrator = OrchestratorScript.new()
	_orchestrator.name = "BattleDedicatedServerOrchestrator"
	if _orchestrator.has_method("configure_bootstrap"):
		_orchestrator.configure_bootstrap({
			"listen_port": listen_port,
			"max_clients": max_clients,
			"authority_host": authority_host,
			"battle_ticket_secret": battle_ticket_secret,
			"resume_window_sec": resume_window_sec,
		})
	add_child(_orchestrator)


func _exit_tree() -> void:
	if _orchestrator != null and _orchestrator.has_method("shutdown"):
		_orchestrator.shutdown(null)


func get_shutdown_name() -> String:
	return "battle_dedicated_server_bootstrap"


func get_shutdown_priority() -> int:
	return 40


func shutdown(_context: Variant) -> void:
	if _orchestrator != null and _orchestrator.has_method("shutdown"):
		_orchestrator.shutdown(_context)


func get_shutdown_metrics() -> Dictionary:
	if _orchestrator != null and _orchestrator.has_method("get_shutdown_metrics"):
		return _orchestrator.get_shutdown_metrics()
	return {
		"shutdown_failed": false,
		"shutdown_complete": true,
		"has_orchestrator": _orchestrator != null,
	}
