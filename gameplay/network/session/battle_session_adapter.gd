class_name BattleSessionAdapter
extends Node

signal adapter_configured()
signal battle_session_started(config: BattleStartConfig)
signal battle_session_stopped()

var start_config: BattleStartConfig = null
var client_session: ClientSession = null
var server_session: ServerSession = null


func bind_sessions(p_client_session: ClientSession, p_server_session: ServerSession) -> void:
	client_session = p_client_session
	server_session = p_server_session
	adapter_configured.emit()


func setup_from_start_config(config: BattleStartConfig) -> void:
	start_config = config


func start_battle() -> void:
	if start_config == null:
		return
	battle_session_started.emit(start_config)


func shutdown_battle() -> void:
	start_config = null
	battle_session_stopped.emit()
