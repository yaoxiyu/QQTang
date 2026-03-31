extends Node

const BattleSessionAdapterScript = preload("res://network/session/battle_session_adapter.gd")
const TickRunnerScript = preload("res://gameplay/simulation/runtime/tick_runner.gd")

@onready var transport_root: Node = $TransportRoot
@onready var session_root: Node = $SessionRoot
@onready var debug_root: Node = $DebugRoot
@onready var debug_panel: Control = $CanvasLayer/DebugPanel
@onready var title_label: Label = $CanvasLayer/DebugPanel/TitleLabel
@onready var mode_label: Label = $CanvasLayer/DebugPanel/ModeLabel
@onready var connection_label: Label = $CanvasLayer/DebugPanel/ConnectionLabel
@onready var host_button: Button = $CanvasLayer/DebugPanel/HostButton
@onready var client_button: Button = $CanvasLayer/DebugPanel/ClientButton
@onready var address_input: LineEdit = $CanvasLayer/DebugPanel/AddressInput
@onready var port_input: LineEdit = $CanvasLayer/DebugPanel/PortInput
@onready var launch_match_button: Button = $CanvasLayer/DebugPanel/LaunchMatchButton
@onready var log_output: RichTextLabel = $CanvasLayer/DebugPanel/LogOutput

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


func _ready() -> void:
	_session_adapter = BattleSessionAdapterScript.new()
	session_root.add_child(_session_adapter)
	_bind_ui()
	_bind_runtime_signals()
	_bind_transport_signals()
	_apply_debug_layout()
	log_output.selection_enabled = true
	address_input.text = "127.0.0.1"
	port_input.text = "9000"
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
	if not host_button.pressed.is_connected(_on_host_pressed):
		host_button.pressed.connect(_on_host_pressed)
	if not client_button.pressed.is_connected(_on_client_pressed):
		client_button.pressed.connect(_on_client_pressed)
	if not launch_match_button.pressed.is_connected(_on_launch_match_pressed):
		launch_match_button.pressed.connect(_on_launch_match_pressed)


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
	_session_adapter.network_bootstrap_start_client_transport(address_input.text.strip_edges(), _resolve_port(), 5.0)
	_log("Client connecting to %s:%d" % [address_input.text.strip_edges(), _resolve_port()])
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
	snapshot.selected_map_id = "default_map"
	snapshot.rule_set_id = "classic"
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
	var port := int(port_input.text.strip_edges().to_int())
	return port if port > 0 else 9000


func _refresh_ui() -> void:
	title_label.text = "Phase4 Network Bootstrap"
	match _mode:
		BootstrapMode.HOST:
			mode_label.text = "Mode: Host"
		BootstrapMode.CLIENT:
			mode_label.text = "Mode: Client"
		_:
			mode_label.text = "Mode: Idle"
	launch_match_button.disabled = _mode != BootstrapMode.HOST


func _refresh_connection_label() -> void:
	if _mode == BootstrapMode.IDLE:
		connection_label.text = "Connection: Disconnected"
		return
	var connected : bool = _session_adapter.network_bootstrap_transport_connected()
	connection_label.text = "Connection: %s (%d peers)" % [
		"Connected" if connected else "Connecting",
		_session_adapter.network_bootstrap_transport_remote_peer_ids().size(),
	]


func _apply_debug_layout() -> void:
	if debug_panel == null:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var panel_width := 520.0
	var panel_height: float = min(max(viewport_size.y - 40.0, 360.0), 760.0)
	debug_panel.position = Vector2(20, 20)
	debug_panel.size = Vector2(panel_width, panel_height)

	title_label.position = Vector2(16, 16)
	title_label.size = Vector2(panel_width - 32, 24)

	mode_label.position = Vector2(16, 44)
	mode_label.size = Vector2(panel_width - 32, 22)

	connection_label.position = Vector2(16, 68)
	connection_label.size = Vector2(panel_width - 32, 22)

	host_button.position = Vector2(16, 104)
	host_button.size = Vector2(110, 32)

	client_button.position = Vector2(136, 104)
	client_button.size = Vector2(110, 32)

	address_input.position = Vector2(16, 146)
	address_input.size = Vector2(320, 32)

	port_input.position = Vector2(346, 146)
	port_input.size = Vector2(80, 32)

	launch_match_button.position = Vector2(16, 188)
	launch_match_button.size = Vector2(160, 34)

	log_output.position = Vector2(16, 234)
	log_output.size = Vector2(panel_width - 32, panel_height - 250)


func _log(message: String) -> void:
	if log_output == null:
		return
	log_output.append_text(message + "\n")


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
