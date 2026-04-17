## DEBUG ONLY
## This transport bootstrap scene is a QA / protocol debug shell.
## It is not a formal product entry for Room, Battle, or Dedicated Server flow.
## LegacyMigration and later formal gameplay entry must continue through:
## - res://scenes/front/room_scene.tscn
## - res://scenes/network/dedicated_server_scene.tscn

extends Node

const BattleSessionAdapterScript = preload("res://network/session/battle_session_adapter.gd")
const TickRunnerScript = preload("res://gameplay/simulation/runtime/tick_runner.gd")
const BattleStartConfigScript = preload("res://gameplay/battle/config/battle_start_config.gd")
const MapCatalogScript = preload("res://content/maps/catalog/map_catalog.gd")
const MapLoaderScript = preload("res://content/maps/runtime/map_loader.gd")
const RuleSetCatalogScript = preload("res://content/rulesets/catalog/rule_set_catalog.gd")
const CharacterCatalogScript = preload("res://content/characters/catalog/character_catalog.gd")
const CharacterLoaderScript = preload("res://content/characters/runtime/character_loader.gd")
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
	_log("Transport debug shell ready")
	_log("DEBUG ONLY: this scene is not the formal room or battle entry")


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
		_log("Host entered debug battle %s" % config.match_id)
	)
	_session_adapter.network_client_match_started.connect(func(config: BattleStartConfig) -> void:
		_active_config = config.duplicate_deep()
		_log("Client entered debug battle %s" % config.match_id)
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
	var config := _build_transport_debug_start_config(remote_peers)
	if config == null or config.match_id.is_empty():
		_log("Host failed to build transport debug config")
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
	_log("Host launched debug match %s for %d peers" % [config.match_id, remote_peers.size() + 1])
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


func _build_transport_debug_start_config(remote_peers: Array[int]) -> BattleStartConfig:
	var map_id := MapCatalogScript.get_default_map_id()
	var rule_id := RuleSetCatalogScript.get_default_rule_id()
	var map_metadata := MapLoaderScript.load_map_metadata(map_id)
	var rule_config := RuleSetCatalogScript.get_rule_metadata(rule_id)
	if map_metadata.is_empty() or rule_config.is_empty():
		return null

	var player_slots: Array[Dictionary] = [{
		"peer_id": 1,
		"player_name": "Host",
		"display_name": "Host",
		"slot_index": 0,
		"spawn_slot": 0,
		"character_id": CharacterCatalogScript.get_default_character_id(),
	}]
	var spawn_assignments: Array[Dictionary] = []
	var spawn_points: Array = map_metadata.get("spawn_points", [])

	for index in range(remote_peers.size()):
		var peer_id := int(remote_peers[index])
		var slot_index := index + 1
		player_slots.append({
			"peer_id": peer_id,
			"player_name": "Client%d" % peer_id,
			"display_name": "Client%d" % peer_id,
			"slot_index": slot_index,
			"spawn_slot": slot_index,
			"character_id": _resolve_debug_character_id(slot_index),
		})

	for index in range(player_slots.size()):
		var spawn_point: Vector2i = spawn_points[index] if index < spawn_points.size() and spawn_points[index] is Vector2i else Vector2i(index + 1, index + 1)
		var player_entry: Dictionary = player_slots[index]
		spawn_assignments.append({
			"peer_id": int(player_entry.get("peer_id", -1)),
			"slot_index": int(player_entry.get("slot_index", -1)),
			"spawn_index": index,
			"spawn_cell_x": spawn_point.x,
			"spawn_cell_y": spawn_point.y,
		})

	var config := BattleStartConfigScript.new()
	config.room_id = "transport_debug_room"
	config.match_id = "transport_debug_match"
	config.map_id = map_id
	config.map_version = int(map_metadata.get("version", BattleStartConfigScript.DEFAULT_MAP_VERSION))
	config.map_content_hash = String(map_metadata.get("content_hash", ""))
	config.rule_set_id = rule_id
	config.players = player_slots.duplicate(true)
	config.player_slots = player_slots.duplicate(true)
	config.spawn_assignments = spawn_assignments
	config.battle_seed = int(Time.get_unix_time_from_system())
	config.start_tick = 0
	config.match_duration_ticks = max(int(rule_config.get("round_time_sec", 180)) * TickRunnerScript.TICK_RATE, 60)
	config.item_spawn_profile_id = String(map_metadata.get("item_spawn_profile_id", BattleStartConfigScript.DEFAULT_ITEM_SPAWN_PROFILE_ID))
	config.character_loadouts = _build_debug_character_loadouts(player_slots)
	config.sort_players()
	return config


func _collect_local_input() -> Dictionary:
	if not has_meta("pressed_direction_stack"):
		set_meta("pressed_direction_stack", [])
	if not has_meta("last_place_pressed"):
		set_meta("last_place_pressed", false)
	var pressed_direction_stack: Array = get_meta("pressed_direction_stack", [])
	_prune_released_directions(pressed_direction_stack)
	_update_direction_stack_entry(pressed_direction_stack, "ui_left", "left")
	_update_direction_stack_entry(pressed_direction_stack, "ui_right", "right")
	_update_direction_stack_entry(pressed_direction_stack, "ui_up", "up")
	_update_direction_stack_entry(pressed_direction_stack, "ui_down", "down")
	set_meta("pressed_direction_stack", pressed_direction_stack)
	var move_x := 0
	var move_y := 0
	if not pressed_direction_stack.is_empty():
		match String(pressed_direction_stack[pressed_direction_stack.size() - 1]):
			"left":
				move_x = -1
			"right":
				move_x = 1
			"up":
				move_y = -1
			"down":
				move_y = 1
	var place_pressed := Input.is_key_pressed(KEY_SPACE)
	var last_place_pressed := bool(get_meta("last_place_pressed", false))
	var place_just_pressed := place_pressed and not last_place_pressed
	set_meta("last_place_pressed", place_pressed)
	return {
		"move_x": move_x,
		"move_y": move_y,
		"action_place": place_just_pressed,
	}


func _update_direction_stack_entry(pressed_direction_stack: Array, action_name: String, direction: String) -> void:
	if Input.is_action_pressed(action_name):
		if Input.is_action_just_pressed(action_name) or not pressed_direction_stack.has(direction):
			pressed_direction_stack.erase(direction)
			pressed_direction_stack.append(direction)


func _prune_released_directions(pressed_direction_stack: Array) -> void:
	var active_directions: Array[String] = []
	if Input.is_action_pressed("ui_left"):
		active_directions.append("left")
	if Input.is_action_pressed("ui_right"):
		active_directions.append("right")
	if Input.is_action_pressed("ui_up"):
		active_directions.append("up")
	if Input.is_action_pressed("ui_down"):
		active_directions.append("down")
	var stale_directions: Array[String] = []
	for direction in pressed_direction_stack:
		var direction_name := String(direction)
		if not active_directions.has(direction_name):
			stale_directions.append(direction_name)
	for direction_name in stale_directions:
		pressed_direction_stack.erase(direction_name)


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


func _resolve_debug_character_id(slot_index: int) -> String:
	var entries := CharacterCatalogScript.get_character_entries()
	if slot_index >= 0 and slot_index < entries.size():
		return String(entries[slot_index].get("id", CharacterCatalogScript.get_default_character_id()))
	return CharacterCatalogScript.get_default_character_id()


func _build_debug_character_loadouts(player_slots: Array[Dictionary]) -> Array[Dictionary]:
	var loadouts: Array[Dictionary] = []
	for player_entry in player_slots:
		loadouts.append(
			CharacterLoaderScript.build_character_loadout(
				String(player_entry.get("character_id", CharacterCatalogScript.get_default_character_id())),
				int(player_entry.get("peer_id", -1))
			)
		)
	return loadouts
