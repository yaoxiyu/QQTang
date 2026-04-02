extends Node2D

const AppRuntimeRootScript = preload("res://app/flow/app_runtime_root.gd")
const TickRunnerScript = preload("res://gameplay/simulation/runtime/tick_runner.gd")
const ItemSpawnSystemScript = preload("res://gameplay/simulation/systems/item_spawn_system.gd")
const BattleExitRecoveryScript = preload("res://gameplay/battle/runtime/battle_exit_recovery.gd")
const RoomReturnRecoveryScript = preload("res://network/session/runtime/room_return_recovery.gd")
const NetworkErrorCodesScript = preload("res://network/runtime/network_error_codes.gd")
const BattleContentManifestBuilderScript = preload("res://gameplay/battle/config/battle_content_manifest_builder.gd")

const TICK_INTERVAL_SEC: float = TickRunnerScript.TICK_DT
const SETTLEMENT_SHOW_DELAY_SEC: float = 0.35

@onready var battle_bootstrap: BattleBootstrap = $BattleBootstrap
@onready var presentation_bridge: BattlePresentationBridge = $BattleBootstrap/PresentationBridge
@onready var battle_hud: BattleHudController = $CanvasLayer/BattleHUD
@onready var battle_meta_panel: BattleMetaPanel = $CanvasLayer/BattleMetaPanel
@onready var battle_meta_map_label: Label = $CanvasLayer/BattleMetaPanel/VBoxContainer/MapNameLabel
@onready var battle_meta_rule_label: Label = $CanvasLayer/BattleMetaPanel/VBoxContainer/RuleNameLabel
@onready var battle_meta_match_label: Label = $CanvasLayer/BattleMetaPanel/VBoxContainer/MatchMetaLabel
@onready var settlement_controller: SettlementController = $CanvasLayer/SettlementPopupAnchor/SettlementController
@onready var battle_camera_controller: BattleCameraController = $BattleCameraController

var _app_runtime: Node = null
var _battle_context: BattleContext = null
var _session_adapter: Node = null
var _tick_accumulator: float = 0.0
var _finished: bool = false
var _pending_settlement_result: BattleResult = null
var _settlement_delay_remaining: float = 0.0
var _post_shutdown_action: String = ""
var _scene_cleanup_queued: bool = false
var _shutting_down: bool = false
var _battle_exit_recovery: BattleExitRecovery = BattleExitRecoveryScript.new()
var _room_return_recovery: RoomReturnRecovery = RoomReturnRecoveryScript.new()
var _content_manifest_builder = BattleContentManifestBuilderScript.new()


func _ready() -> void:
	call_deferred("_initialize_runtime")


func _process(delta: float) -> void:
	if settlement_controller.visible:
		return
	if _shutting_down:
		return
	if _pending_settlement_result != null:
		_settlement_delay_remaining = max(_settlement_delay_remaining - delta, 0.0)
		if _settlement_delay_remaining <= 0.0:
			_show_pending_settlement()
		return
	if _session_adapter == null or _battle_context == null or _finished:
		return

	_tick_accumulator += delta
	while _tick_accumulator >= TICK_INTERVAL_SEC and not _finished:
		_tick_accumulator -= TICK_INTERVAL_SEC
		_session_adapter.advance_authoritative_tick(_collect_local_input())


func _initialize_runtime() -> void:
	_app_runtime = AppRuntimeRootScript.ensure_in_tree(get_tree())
	_session_adapter = _app_runtime.battle_session_adapter if _app_runtime != null else null
	if _app_runtime != null:
		_app_runtime.register_battle_modules(self, battle_bootstrap, presentation_bridge, battle_hud, battle_camera_controller, settlement_controller)
	_connect_session_signals()
	if not settlement_controller.return_to_room_requested.is_connected(_on_settlement_return_to_room_requested):
		settlement_controller.return_to_room_requested.connect(_on_settlement_return_to_room_requested)
	if not settlement_controller.rematch_requested.is_connected(_on_settlement_rematch_requested):
		settlement_controller.rematch_requested.connect(_on_settlement_rematch_requested)

	if _session_adapter != null:
		_session_adapter.start_battle()


func _exit_tree() -> void:
	if _app_runtime != null:
		_app_runtime.unregister_battle_modules(self)
	if settlement_controller.return_to_room_requested.is_connected(_on_settlement_return_to_room_requested):
		settlement_controller.return_to_room_requested.disconnect(_on_settlement_return_to_room_requested)
	if settlement_controller.rematch_requested.is_connected(_on_settlement_rematch_requested):
		settlement_controller.rematch_requested.disconnect(_on_settlement_rematch_requested)
	_disconnect_session_signals(true)


func _unhandled_input(event: InputEvent) -> void:
	if _shutting_down:
		return
	if event.is_action_pressed("ui_accept") and settlement_controller.visible:
		settlement_controller.request_return_to_room()
		return
	if event is InputEventKey and event.pressed and not event.echo and _session_adapter != null:
		match event.keycode:
			KEY_J:
				_session_adapter.cycle_latency_profile()
				battle_hud.match_message_panel.apply_message("Latency Profile %s" % _session_adapter.get_network_profile_summary())
			KEY_K:
				_session_adapter.cycle_loss_profile()
				battle_hud.match_message_panel.apply_message("Loss Profile %s" % _session_adapter.get_network_profile_summary())
			KEY_L:
				_session_adapter.arm_force_prediction_divergence()
				battle_hud.match_message_panel.apply_message("Force divergence armed")
			KEY_I:
				var drop_rate: int = ItemSpawnSystemScript.cycle_debug_drop_rate_percent()
				battle_hud.match_message_panel.apply_message("Drop Rate %d%%" % drop_rate)
			KEY_O:
				var remote_debug_enabled: bool = _session_adapter.toggle_remote_debug_inputs()
				battle_hud.match_message_panel.apply_message("Remote Debug %s" % ("On" if remote_debug_enabled else "Off"))


func _on_battle_context_created(context: BattleContext) -> void:
	if context == null or context.sim_world == null:
		if _app_runtime != null and _app_runtime.error_router != null:
			_app_runtime.error_router.route_error(
				_app_runtime,
				NetworkErrorCodesScript.MATCH_START_RUNTIME_BOOTSTRAP_FAILED,
				"battle_start",
				"battle_context_created",
				"Battle runtime bootstrap failed",
				{},
				"return_to_room",
				true
			)
		battle_hud.match_message_panel.apply_message("Missing battle runtime")
		return

	_battle_context = context
	var resolved_manifest: Dictionary = {}
	if _app_runtime != null and not _app_runtime.current_battle_content_manifest.is_empty():
		resolved_manifest = _app_runtime.current_battle_content_manifest.duplicate(true)
	elif _battle_context != null and _battle_context.battle_start_config != null:
		resolved_manifest = _content_manifest_builder.build_for_start_config(_battle_context.battle_start_config)
	_battle_context.battle_content_manifest = resolved_manifest
	_tick_accumulator = 0.0
	_finished = false
	_pending_settlement_result = null
	_settlement_delay_remaining = 0.0
	_post_shutdown_action = ""
	_scene_cleanup_queued = false
	_shutting_down = false
	battle_bootstrap.bind_context(_battle_context)
	if _app_runtime != null and _app_runtime.room_session_controller != null and _app_runtime.room_session_controller.has_method("mark_match_started"):
		var match_id: String = _app_runtime.current_start_config.match_id if _app_runtime.current_start_config != null else ""
		_app_runtime.room_session_controller.mark_match_started(match_id)
	battle_camera_controller.configure_from_world(_battle_context.sim_world, presentation_bridge.cell_size)
	presentation_bridge.consume_tick_result({}, _battle_context.sim_world, [])
	battle_hud.set_local_player_entity_id(_resolve_local_player_entity_id())
	_apply_battle_metadata()
	call_deferred("_apply_battle_metadata")
	battle_hud.consume_battle_state(_battle_context.sim_world)
	if _session_adapter != null:
		battle_hud.consume_network_metrics(_session_adapter.build_runtime_metrics_snapshot())
	battle_hud.match_message_panel.apply_message(
		"J Latency  K Loss  L ForceRollback  I DropRate %d%%  O RemoteDebug %s" % [
			ItemSpawnSystemScript.get_debug_drop_rate_percent(),
			"On" if _session_adapter.use_remote_debug_inputs else "Off"
		]
	)


func _on_authoritative_tick_completed(context: BattleContext, tick_result: Dictionary, metrics: Dictionary) -> void:
	if context == null or context.sim_world == null:
		return
	presentation_bridge.consume_tick_result(tick_result, context.sim_world, tick_result.get("events", []))
	_consume_battle_events(tick_result.get("events", []))
	battle_hud.consume_battle_state(context.sim_world)
	battle_hud.consume_network_metrics(metrics)


func _on_battle_finished_authoritatively(result: BattleResult) -> void:
	if _finished:
		return
	_finished = true
	if _app_runtime != null and _app_runtime.room_session_controller != null and _app_runtime.room_session_controller.has_method("mark_match_finished"):
		var match_id: String = _app_runtime.current_start_config.match_id if _app_runtime != null and _app_runtime.current_start_config != null else ""
		_app_runtime.room_session_controller.mark_match_finished(match_id)
	_pending_settlement_result = result.duplicate_deep() if result != null else null
	_settlement_delay_remaining = SETTLEMENT_SHOW_DELAY_SEC
	battle_hud.match_message_panel.apply_message("Battle resolved...")


func _on_battle_session_stopped() -> void:
	if _app_runtime != null:
		_app_runtime.clear_battle_payload()
	_battle_context = null
	_finished = false
	_tick_accumulator = 0.0
	_pending_settlement_result = null
	_settlement_delay_remaining = 0.0
	_shutting_down = false


func _on_transport_runtime_error(code: int, message: String) -> void:
	if _app_runtime != null and _app_runtime.error_router != null:
		_app_runtime.error_router.route_error(
			_app_runtime,
			NetworkErrorCodesScript.BATTLE_DISCONNECTED,
			"transport",
			"battle_runtime",
			"Battle transport disconnected",
			{
				"transport_code": code,
				"transport_message": message,
			},
			"return_to_room",
			true
		)
	if battle_hud != null and battle_hud.match_message_panel != null:
		battle_hud.match_message_panel.apply_message("Transport error: %s" % message)


func _on_settlement_return_to_room_requested() -> void:
	_request_post_shutdown_action("return_to_room")


func _on_settlement_rematch_requested() -> void:
	_request_post_shutdown_action("rematch")


func _request_post_shutdown_action(action: String) -> void:
	if _post_shutdown_action != "":
		return
	_post_shutdown_action = action
	_shutdown_active_battle()
	_complete_post_shutdown_action()


func _complete_return_to_room() -> void:
	if _app_runtime == null:
		return
	_room_return_recovery.recover(_app_runtime, _post_shutdown_action)


func _consume_battle_events(events: Array) -> void:
	for event in events:
		if event == null:
			continue
		match int(event.event_type):
			SimEvent.EventType.PLAYER_KILLED:
				battle_hud.on_player_killed_event(event)
			SimEvent.EventType.ITEM_PICKED:
				battle_hud.on_item_picked_event(event, _resolve_local_player_entity_id())
			SimEvent.EventType.MATCH_ENDED:
				var resolved_peer_id := -1
				if _app_runtime != null and _app_runtime.current_start_config != null:
					resolved_peer_id = int(_app_runtime.current_start_config.controlled_peer_id)
				if resolved_peer_id <= 0 and _app_runtime != null:
					resolved_peer_id = _app_runtime.local_peer_id
				battle_hud.on_match_ended_event(event, resolved_peer_id)


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


func _show_pending_settlement() -> void:
	if _pending_settlement_result == null:
		return
	if _app_runtime != null and _app_runtime.front_flow != null:
		_app_runtime.front_flow.on_battle_finished(_pending_settlement_result)
	settlement_controller.show_result(_pending_settlement_result)
	battle_hud.match_message_panel.apply_message("Press Enter to return room")
	_pending_settlement_result = null
	_settlement_delay_remaining = 0.0


func _on_prediction_debug_event(event: Dictionary) -> void:
	if event.is_empty() or battle_hud.match_message_panel == null:
		return
	var message: String = str(event.get("message", ""))
	if not message.is_empty():
		battle_hud.match_message_panel.apply_message(message)


func _shutdown_active_battle() -> void:
	_shutting_down = true
	_tick_accumulator = 0.0
	_battle_exit_recovery.recover(
		_session_adapter,
		battle_bootstrap,
		presentation_bridge,
		battle_hud,
		settlement_controller,
		Callable(self, "_disconnect_session_signals")
	)


func _complete_post_shutdown_action() -> void:
	if _app_runtime != null:
		_app_runtime.unregister_battle_modules(self)
	match _post_shutdown_action:
		"return_to_room":
			_complete_return_to_room()
		"rematch":
			_complete_return_to_room()
		_:
			pass
	_post_shutdown_action = ""
	_queue_scene_cleanup()


func _queue_scene_cleanup() -> void:
	if _scene_cleanup_queued:
		return
	_scene_cleanup_queued = true
	call_deferred("_cleanup_detached_battle_scene")


func _cleanup_detached_battle_scene() -> void:
	if not is_instance_valid(self):
		return
	queue_free()


func _resolve_local_player_entity_id() -> int:
	if _battle_context == null or _battle_context.sim_world == null or _app_runtime == null or _app_runtime.current_start_config == null:
		return -1
	var controlled_peer_id := int(_app_runtime.current_start_config.controlled_peer_id)
	if controlled_peer_id <= 0:
		controlled_peer_id = _app_runtime.local_peer_id
	for player_entry in _app_runtime.current_start_config.players:
		if int(player_entry.get("peer_id", -1)) != controlled_peer_id:
			continue
		var slot_index: int = int(player_entry.get("slot_index", -1))
		for player_id in _battle_context.sim_world.state.players.active_ids:
			var player: PlayerState = _battle_context.sim_world.state.players.get_player(player_id)
			if player != null and player.player_slot == slot_index:
				return player.entity_id
	return -1


func _apply_battle_metadata() -> void:
	if battle_hud == null:
		return
	var resolved_start_config: BattleStartConfig = null
	if _battle_context != null and _battle_context.battle_start_config != null:
		resolved_start_config = _battle_context.battle_start_config
	elif _app_runtime != null and _app_runtime.current_start_config != null:
		resolved_start_config = _app_runtime.current_start_config
	if resolved_start_config == null:
		return
	var manifest: Dictionary = {}
	if _battle_context != null and not _battle_context.battle_content_manifest.is_empty():
		manifest = _battle_context.battle_content_manifest
	elif _app_runtime != null and not _app_runtime.current_battle_content_manifest.is_empty():
		manifest = _app_runtime.current_battle_content_manifest
	if manifest.is_empty():
		manifest = _content_manifest_builder.build_for_start_config(resolved_start_config)
		if _battle_context != null:
			_battle_context.battle_content_manifest = manifest.duplicate(true)
	var ui_summary: Dictionary = manifest.get("ui_summary", {})
	var match_meta_text := "Match: %s | Profile: %s" % [
		String(resolved_start_config.match_id),
		String(ui_summary.get("item_profile_id", resolved_start_config.item_spawn_profile_id)),
	]
	var item_brief := String(ui_summary.get("item_brief", ""))
	if not item_brief.is_empty():
		match_meta_text = "%s | %s" % [match_meta_text, item_brief]
	battle_hud.set_battle_metadata(
		String(ui_summary.get("map_display_name", resolved_start_config.map_id)),
		String(ui_summary.get("rule_display_name", resolved_start_config.rule_set_id)),
		match_meta_text
	)
	var resolved_map_display_name := String(ui_summary.get("map_display_name", resolved_start_config.map_id))
	var resolved_rule_display_name := String(ui_summary.get("rule_display_name", resolved_start_config.rule_set_id))
	if battle_meta_panel != null:
		battle_meta_panel.apply_metadata(
			resolved_map_display_name,
			resolved_rule_display_name,
			match_meta_text
		)
	if battle_meta_map_label != null:
		battle_meta_map_label.text = "地图: %s" % resolved_map_display_name
	if battle_meta_rule_label != null:
		battle_meta_rule_label.text = "规则: %s" % resolved_rule_display_name
	if battle_meta_match_label != null:
		battle_meta_match_label.text = match_meta_text


func _connect_session_signals() -> void:
	if _session_adapter == null:
		return
	if not _session_adapter.battle_context_created.is_connected(_on_battle_context_created):
		_session_adapter.battle_context_created.connect(_on_battle_context_created)
	if not _session_adapter.authoritative_tick_completed.is_connected(_on_authoritative_tick_completed):
		_session_adapter.authoritative_tick_completed.connect(_on_authoritative_tick_completed)
	if not _session_adapter.battle_finished_authoritatively.is_connected(_on_battle_finished_authoritatively):
		_session_adapter.battle_finished_authoritatively.connect(_on_battle_finished_authoritatively)
	if not _session_adapter.battle_session_stopped.is_connected(_on_battle_session_stopped):
		_session_adapter.battle_session_stopped.connect(_on_battle_session_stopped)
	if not _session_adapter.prediction_debug_event.is_connected(_on_prediction_debug_event):
		_session_adapter.prediction_debug_event.connect(_on_prediction_debug_event)
	if not _session_adapter.network_transport_error.is_connected(_on_transport_runtime_error):
		_session_adapter.network_transport_error.connect(_on_transport_runtime_error)


func _disconnect_session_signals(include_stop_signal: bool) -> void:
	if _session_adapter == null:
		return
	if _session_adapter.battle_context_created.is_connected(_on_battle_context_created):
		_session_adapter.battle_context_created.disconnect(_on_battle_context_created)
	if _session_adapter.authoritative_tick_completed.is_connected(_on_authoritative_tick_completed):
		_session_adapter.authoritative_tick_completed.disconnect(_on_authoritative_tick_completed)
	if _session_adapter.battle_finished_authoritatively.is_connected(_on_battle_finished_authoritatively):
		_session_adapter.battle_finished_authoritatively.disconnect(_on_battle_finished_authoritatively)
	if include_stop_signal and _session_adapter.battle_session_stopped.is_connected(_on_battle_session_stopped):
		_session_adapter.battle_session_stopped.disconnect(_on_battle_session_stopped)
	if _session_adapter.prediction_debug_event.is_connected(_on_prediction_debug_event):
		_session_adapter.prediction_debug_event.disconnect(_on_prediction_debug_event)
	if _session_adapter.network_transport_error.is_connected(_on_transport_runtime_error):
		_session_adapter.network_transport_error.disconnect(_on_transport_runtime_error)

