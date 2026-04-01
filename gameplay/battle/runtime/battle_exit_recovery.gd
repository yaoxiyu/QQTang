class_name BattleExitRecovery
extends RefCounted


func recover(
	session_adapter: Node,
	bootstrap: BattleBootstrap,
	bridge: BattlePresentationBridge,
	hud: BattleHudController,
	settlement_controller: SettlementController,
	disconnect_session_signals: Callable
) -> void:
	if disconnect_session_signals.is_valid():
		disconnect_session_signals.call(false)
	if session_adapter != null and session_adapter.has_method("shutdown_battle"):
		session_adapter.shutdown_battle()
	if bootstrap != null:
		bootstrap.release_context()
	if bridge != null:
		bridge.shutdown_bridge()
	if hud != null:
		hud.reset_hud()
	if settlement_controller != null:
		settlement_controller.reset_settlement()
