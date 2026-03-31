extends Node

const BattleSessionAdapterScript = preload("res://network/session/battle_session_adapter.gd")
const TickRunnerScript = preload("res://gameplay/simulation/runtime/tick_runner.gd")
const MapCatalogScript = preload("res://content/maps/catalog/map_catalog.gd")
const RuleCatalogScript = preload("res://content/rules/rule_catalog.gd")
const NetworkDebugPanelScript = preload("res://network/runtime/network_debug_panel.gd")

@onready var transport_root: Node = $TransportRoot
@onready var session_root: Node = $SessionRoot
@onready var debug_root: Node = $DebugRoot
@onready var debug_panel: Control = $CanvasLayer/DebugPanel

enum BootstrapMode {
	IDLE,
	HOST,
	CLIENT,
}

var _mode: int = BootstrapMode.IDLE
var _session_adapter = null
var _tick_accumulator: float = 0.0
var _active_config: BattleStartConfig = null
var _host_launched: bool = false
var _host_launch_delay_ticks: int = 0
var _client_join_sent: bool = false
var _last_result: BattleResult = null
var _debug_panel_controller: NetworkDebugPanel = null


func _ready() -> void:
	_session_adapter = BattleSessionAdapterScript.new()
	session_root.add_child(_session_adapter)
	_debug_panel_controller = NetworkDebugPanelScript.new()
	_debug_panel_controller.setup(debug_panel)
	_bind_ui()
	_bind_runtime_signals()
	_bind_transport_signals()
	_apply_debug_layout()
	_debug_panel_controller.initialize_defaults()
	_refresh_ui()
	_log("Network bootstrap ready")


func _process(delta: float) -> void:
	_session_adapter.network_bootstrap_poll_transport()

	_tick_accumulator += delta
	while _tick_accumulator >= TickRunnerScript.TICK_DT:
		_tick_accumulator -= TickRunnerScript.TICK_DT
		_process_network_tick()

	_refresh_connection_label()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_SIZE_CHANGED:
		_apply_debug_layout()


func _exit_tree() -> void:
	_shutdown_all()


func _bind_ui() -> void:
	if _debug_panel_controller != null:
		_debug_panel_controller.bind_actions(
			Callable(self, "_on_host_pressed"),
			Callable(self, "_on_client_pressed"),
			Callable(self, "_on_launch_match_pressed")
		)


func _bind_runtime_signals() -> void:
	_session_adapter.network_log_event.connect(_log)
	_session_adapter.network_host_match_started.connect(func(config: BattleStartConfig) -> void:
		_log("Host entered battle %s" % config.match_id)
	)
	_session_adapter.network_client_match_started.connect(func(config: BattleStartConfig) -> void:
		_active_config = config.duplicate_deep()
		_log("Client entered battle %s" % config.match_id)
	)
	_session_adapter.prediction_debug_event.connect(func(event: Dictionary) -> void:
		_log(str(event.get("message", "prediction event")))
	)
	_session_adapter.network_battle_finished.connect(_on_adapter_battle_finished)


func _bind_transport_signals() -> void:
	_session_adapter.network_transport_connected.connect(func() -> void:
		_log("Transport connected")
		if _mode == BootstrapMode.CLIENT and not _client_join_sent:
			_client_join_sent = true
			_session_adapter.network_bootstrap_set_local_peer_id(_session_adapter.network_bootstrap_transport_local_peer_id())
			_session_adapter.network_bootstrap_send_to_peer(1, {
				"message_type": "JOIN_BATTLE_REQUEST",
				"msg_type": "JOIN_BATTLE_REQUEST",
				"sender_peer_id": _session_adapter.network_bootstrap_transport_local_peer_id(),
			})
	)
	_session_adapter.network_transport_disconnected.connect(func() -> void:
		_log("Transport disconnected")
	)
	_session_adapter.network_transport_peer_connected.connect(func(peer_id: int) -> void:
		_log("Peer connected: %d" % peer_id)
	)
	_session_adapter.network_transport_peer_disconnected.connect(func(peer_id: int) -> void:
		_log("Peer disconnected: %d" % peer_id)
	)
	_session_adapter.network_transport_error.connect(func(code: int, message: String) -> void:
		_log("Transport error %d: %s" % [code, message])
	)


func _on_host_pressed() -> void:
	_shutdown_all()
	_mode = BootstrapMode.HOST
	_session_adapter.network_bootstrap_configure_host(1)
	_session_adapter.network_bootstrap_start_host_transport(_resolve_port(), 4)
	_log("Host transport initialized on port %d" % _resolve_port())
	_refresh_ui()


func _on_client_pressed() -> void:
	_shutdown_all()
	_mode = BootstrapMode.CLIENT
	_session_adapter.network_bootstrap_configure_client(0)
	var address := _resolve_address()
	var port := _resolve_port()
	_session_adapter.network_bootstrap_start_client_transport(address, port, 5.0)
	_log("Client connecting to %s:%d" % [address, port])
	_refresh_ui()


func _on_launch_match_pressed() -> void:
	if _mode != BootstrapMode.HOST or not _session_adapter.network_bootstrap_transport_connected():
		_log("Launch Match is only available for host mode")
		return
	var remote_peers : Array[int] = _session_adapter.network_bootstrap_transport_remote_peer_ids()
	if remote_peers.is_empty():
		_log("Host cannot launch: no clients connected")
		return
	var snapshot := _build_debug_room_snapshot(remote_peers)
	var config: BattleStartConfig = _session_adapter.network_bootstrap_build_start_config(snapshot)
	if config == null or config.match_id.is_empty():
		_log("Host failed to build BattleStartConfig")
		return
	config.match_duration_ticks = min(config.match_duration_ticks, 60)
	_active_config = config.duplicate_deep()
	if not _session_adapter.network_bootstrap_start_host_match(config):
		_log("Host failed to start authority runtime")
		return
	_host_launched = true
	var accepted_message := {
		"message_type": "JOIN_BATTLE_ACCEPTED",
		"msg_type": "JOIN_BATTLE_ACCEPTED",
		"protocol_version": config.protocol_version,
		"match_id": config.match_id,
		"sender_peer_id": 1,
		"start_config": config.to_dict(),
	}
	_host_launch_delay_ticks = 5
	_log("Host broadcasting JOIN_BATTLE_ACCEPTED to peers=%s" % str(remote_peers))
	_session_adapter.network_bootstrap_broadcast(accepted_message)
	_log("Host launched match %s for %d peers" % [config.match_id, remote_peers.size() + 1])
	_refresh_ui()


func _process_network_tick() -> void:
	match _mode:
		BootstrapMode.HOST:
			if _host_launched and _session_adapter.network_bootstrap_is_host_match_running():
				if _host_launch_delay_ticks > 0:
					_host_launch_delay_ticks -= 1
					return
				for message in _session_adapter.network_bootstrap_build_host_tick_messages(_collect_local_input()):
					_session_adapter.network_bootstrap_broadcast(message)
		BootstrapMode.CLIENT:
			if _session_adapter.network_bootstrap_is_client_active() and _session_adapter.network_bootstrap_transport_connected():
				var input_message : Dictionary = _session_adapter.network_bootstrap_build_client_input_message(_collect_local_input())
				if not input_message.is_empty():
					_session_adapter.network_bootstrap_send_to_peer(1, input_message)
		_:
			pass


func _build_debug_room_snapshot(remote_peers: Array[int]) -> RoomSnapshot:
	var snapshot := RoomSnapshot.new()
	snapshot.room_id = "phase4_network_room"
	snapshot.owner_peer_id = 1
	snapshot.selected_map_id = MapCatalogScript.get_default_map_id()
	snapshot.rule_set_id = RuleCatalogScript.get_default_rule_id()
	snapshot.all_ready = true
	snapshot.max_players = remote_peers.size() + 1

	var host_member := RoomMemberState.new()
	host_member.peer_id = 1
	host_member.player_name = "Host"
	host_member.ready = true
	host_member.slot_index = 0
	host_member.character_id = "hero_1"
	snapshot.members.append(host_member)

	var next_slot := 1
	for peer_id in remote_peers:
		var member := RoomMemberState.new()
		member.peer_id = int(peer_id)
		member.player_name = "Client%d" % peer_id
		member.ready = true
		member.slot_index = next_slot
		member.character_id = "hero_%d" % (next_slot + 1)
		snapshot.members.append(member)
		next_slot += 1

	return snapshot


func _collect_local_input() -> Dictionary:
	var move_x := 0
	var move_y := 0
	if Input.is_action_pressed("ui_left"):
		move_x -= 1
	if Input.is_action_pressed("ui_right"):
		move_x += 1
	if move_x == 0:
		if Input.is_action_pressed("ui_up"):
			move_y -= 1
		if Input.is_action_pressed("ui_down"):
			move_y += 1
	return {
		"move_x": move_x,
		"move_y": move_y,
		"action_place": Input.is_key_pressed(KEY_SPACE),
	}


func _resolve_port() -> int:
	return _debug_panel_controller.get_port(9000) if _debug_panel_controller != null else 9000


func _resolve_address() -> String:
	return _debug_panel_controller.get_address() if _debug_panel_controller != null else "127.0.0.1"


func _refresh_ui() -> void:
	var mode_name := "Idle"
	match _mode:
		BootstrapMode.HOST:
			mode_name = "Host"
		BootstrapMode.CLIENT:
			mode_name = "Client"
	if _debug_panel_controller != null:
		_debug_panel_controller.refresh_mode(mode_name, _mode == BootstrapMode.HOST)


func _refresh_connection_label() -> void:
	if _debug_panel_controller == null:
		return
	var is_idle := _mode == BootstrapMode.IDLE
	var connected : bool = _session_adapter.network_bootstrap_transport_connected()
	var remote_peer_count : int = _session_adapter.network_bootstrap_transport_remote_peer_ids().size()
	_debug_panel_controller.refresh_connection(is_idle, connected, remote_peer_count)


func _apply_debug_layout() -> void:
	if _debug_panel_controller == null:
		return
	_debug_panel_controller.apply_layout(get_viewport().get_visible_rect().size)


func _log(message: String) -> void:
	if _debug_panel_controller != null:
		_debug_panel_controller.log(message)


func _shutdown_all() -> void:
	_host_launched = false
	_host_launch_delay_ticks = 0
	_client_join_sent = false
	_active_config = null
	_last_result = null
	_tick_accumulator = 0.0
	if _session_adapter != null:
		_session_adapter.network_bootstrap_shutdown()
	_mode = BootstrapMode.IDLE
	_refresh_ui()


func _on_adapter_battle_finished(result: BattleResult, is_host: bool) -> void:
	_last_result = result.duplicate_deep()
	if is_host:
		_log("Host finished match: %s winners=%s" % [result.finish_reason, str(result.winner_peer_ids)])
	else:
		var metrics : Dictionary = _session_adapter.network_bootstrap_build_client_metrics()
		_log("Client finished match: %s winners=%s rollback=%d correction=%d" % [
			result.finish_reason,
			str(result.winner_peer_ids),
			int(metrics.get("rollback_count", 0)),
			int(metrics.get("correction_count", 0)),
		])
	_refresh_ui()
