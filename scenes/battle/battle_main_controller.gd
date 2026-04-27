extends Node2D

const AppRuntimeRootScript = preload("res://app/flow/app_runtime_root.gd")
const TickRunnerScript = preload("res://gameplay/simulation/runtime/tick_runner.gd")
const ItemSpawnSystemScript = preload("res://gameplay/simulation/systems/item_spawn_system.gd")
const BattleExitRecoveryScript = preload("res://gameplay/battle/runtime/battle_exit_recovery.gd")
const RoomReturnRecoveryScript = preload("res://network/session/runtime/room_return_recovery.gd")
const NetworkErrorCodesScript = preload("res://network/runtime/network_error_codes.gd")
const BattleFlowCoordinatorScript = preload("res://scenes/battle/battle_flow_coordinator.gd")
const BattleResultTransitionControllerScript = preload("res://scenes/battle/battle_result_transition_controller.gd")
const RuntimeShutdownCoordinatorScript = preload("res://app/runtime/runtime_shutdown_coordinator.gd")
const LogFrontScript = preload("res://app/logging/log_front.gd")
const TRACE_PREFIX := "[qq_battle_trace]"
const ONLINE_LOG_PREFIX := "[QQT_ONLINE]"

const TICK_INTERVAL_SEC: float = TickRunnerScript.TICK_DT
const SETTLEMENT_SHOW_DELAY_SEC: float = 0.35
const SETTLEMENT_SYNC_RETRY_DELAYS_SEC: Array[float] = [1.0, 2.0, 4.0, 4.0, 4.0]

@onready var battle_bootstrap: BattleBootstrap = $BattleBootstrap
@onready var presentation_bridge: BattlePresentationBridge = $BattleBootstrap/PresentationBridge
@onready var battle_hud: BattleHudController = $CanvasLayer/BattleHUD
@onready var battle_meta_panel: BattleMetaPanel = $CanvasLayer/BattleMetaPanel
@onready var battle_meta_map_label: Label = $CanvasLayer/BattleMetaPanel/VBoxContainer/MapNameLabel
@onready var battle_meta_rule_label: Label = $CanvasLayer/BattleMetaPanel/VBoxContainer/RuleNameLabel
@onready var battle_meta_match_label: Label = $CanvasLayer/BattleMetaPanel/VBoxContainer/MatchMetaLabel
@onready var battle_meta_character_label: Label = $CanvasLayer/BattleMetaPanel/VBoxContainer/CharacterNameLabel
@onready var battle_meta_bubble_label: Label = $CanvasLayer/BattleMetaPanel/VBoxContainer/BubbleStyleLabel
@onready var settlement_controller: SettlementController = $CanvasLayer/SettlementPopupAnchor/SettlementController
@onready var battle_camera_controller: BattleCameraController = $BattleCameraController
@onready var map_theme_environment_controller: MapThemeEnvironmentController = $MapThemeEnvironmentController
@onready var world_root: Node2D = $WorldRoot
@onready var canvas_layer: CanvasLayer = $CanvasLayer
@onready var map_root: BattleMapViewController = $WorldRoot/MapRoot

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
var _settlement_sync_token: int = 0
var _battle_exit_recovery: BattleExitRecovery = BattleExitRecoveryScript.new()
var _room_return_recovery: RoomReturnRecovery = RoomReturnRecoveryScript.new()
var _battle_flow_coordinator = BattleFlowCoordinatorScript.new()
var _battle_result_transition_controller = BattleResultTransitionControllerScript.new()
var _shutdown_coordinator: RefCounted = RuntimeShutdownCoordinatorScript.new()
var _shutdown_complete: bool = false
var _pressed_direction_stack: Array[String] = []
var _direction_tap_stack: Array[String] = []
var _last_place_pressed: bool = false
var _place_action_latched: bool = false
var _runtime_bound: bool = false
var _battle_visuals_released: bool = false
var _runtime_reparenting: bool = false


func _ready() -> void:
	_shutdown_coordinator.register_handle(self)
	_set_battle_visuals_available(false)
	call_deferred("_bind_runtime")


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
	if _requires_dedicated_authority_opening() and not _battle_visuals_released:
		if _session_adapter.has_method("poll_dedicated_client_transport"):
			_session_adapter.poll_dedicated_client_transport()
		return

	_tick_accumulator += delta
	while _tick_accumulator >= TICK_INTERVAL_SEC and not _finished:
		_tick_accumulator -= TICK_INTERVAL_SEC
		_session_adapter.advance_authoritative_tick(_collect_local_input())


func _bind_runtime() -> void:
	_app_runtime = AppRuntimeRootScript.get_existing(get_tree())
	if _app_runtime == null:
		get_tree().change_scene_to_file("res://scenes/front/boot_scene.tscn")
		return
	if _app_runtime.has_method("is_runtime_ready") and _app_runtime.is_runtime_ready():
		_initialize_runtime()
		return
	if _app_runtime.has_signal("runtime_ready") and not _app_runtime.runtime_ready.is_connected(_initialize_runtime):
		_app_runtime.runtime_ready.connect(_initialize_runtime, CONNECT_ONE_SHOT)


func _initialize_runtime() -> void:
	if _runtime_bound:
		return
	_runtime_bound = true
	_session_adapter = _app_runtime.battle_session_adapter if _app_runtime != null else null
	if _app_runtime != null and _app_runtime.current_start_config == null:
		# Build BattleStartConfig from BattleEntryContext (battle ticket flow).
		var battle_entry_ctx = _app_runtime.current_battle_entry_context
		if battle_entry_ctx != null and battle_entry_ctx.is_valid():
			var config: BattleStartConfig = _battle_flow_coordinator.build_start_config_from_battle_entry(battle_entry_ctx)
			_app_runtime.apply_canonical_start_config(config)
		elif _session_adapter != null:
			var adapter_config: BattleStartConfig = _session_adapter.get("start_config")
			if adapter_config != null:
				_app_runtime.apply_canonical_start_config(adapter_config)
	if _app_runtime != null:
		_app_runtime.register_battle_modules(self, battle_bootstrap, presentation_bridge, battle_hud, battle_camera_controller, settlement_controller)
	_connect_session_signals()
	if not settlement_controller.return_to_room_requested.is_connected(_on_settlement_return_to_room_requested):
		settlement_controller.return_to_room_requested.connect(_on_settlement_return_to_room_requested)
	if not settlement_controller.rematch_requested.is_connected(_on_settlement_rematch_requested):
		settlement_controller.rematch_requested.connect(_on_settlement_rematch_requested)

	if _session_adapter != null:
		if _app_runtime != null and _app_runtime.current_resume_snapshot != null:
			_session_adapter.apply_resume_snapshot(_app_runtime.current_resume_snapshot)
		_session_adapter.start_battle()


func _exit_tree() -> void:
	if _runtime_reparenting:
		return
	_shutdown_coordinator.shutdown_all("battle_main_exit", false)


func begin_runtime_reparent() -> void:
	_runtime_reparenting = true


func end_runtime_reparent() -> void:
	_runtime_reparenting = false


func get_shutdown_name() -> String:
	return "battle_main_controller"


func get_shutdown_priority() -> int:
	return 70


func shutdown(_context: Variant) -> void:
	if _shutdown_complete:
		return
	_shutdown_complete = true
	if _app_runtime != null:
		_app_runtime.unregister_battle_modules(self)
	if settlement_controller.return_to_room_requested.is_connected(_on_settlement_return_to_room_requested):
		settlement_controller.return_to_room_requested.disconnect(_on_settlement_return_to_room_requested)
	if settlement_controller.rematch_requested.is_connected(_on_settlement_rematch_requested):
		settlement_controller.rematch_requested.disconnect(_on_settlement_rematch_requested)
	_disconnect_session_signals(true)
	_shutdown_active_battle()


func get_shutdown_metrics() -> Dictionary:
	return {
		"shutdown_failed": false,
		"shutdown_complete": _shutdown_complete,
		"session_bound": _session_adapter != null,
	}


func _unhandled_input(event: InputEvent) -> void:
	if _shutting_down:
		return
	if _requires_dedicated_authority_opening() and not _battle_visuals_released:
		return
	if event.is_action_pressed("ui_accept") and settlement_controller.visible:
		settlement_controller.request_return_to_room()
		return
	if event.is_action_pressed("ui_left"):
		_push_direction("left")
		_latch_direction_tap("left")
	elif event.is_action_released("ui_left"):
		_remove_direction("left")
	if event.is_action_pressed("ui_right"):
		_push_direction("right")
		_latch_direction_tap("right")
	elif event.is_action_released("ui_right"):
		_remove_direction("right")
	if event.is_action_pressed("ui_up"):
		_push_direction("up")
		_latch_direction_tap("up")
	elif event.is_action_released("ui_up"):
		_remove_direction("up")
	if event.is_action_pressed("ui_down"):
		_push_direction("down")
		_latch_direction_tap("down")
	elif event.is_action_released("ui_down"):
		_remove_direction("down")
	if event is InputEventKey and event.pressed and not event.echo and _session_adapter != null:
		match event.keycode:
			KEY_SPACE:
				_place_action_latched = true
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
	if _app_runtime != null and _app_runtime.current_start_config == null and _battle_context.battle_start_config != null:
		_app_runtime.apply_canonical_start_config(_battle_context.battle_start_config)
	_tick_accumulator = 0.0
	_finished = false
	_pending_settlement_result = null
	_settlement_delay_remaining = 0.0
	_post_shutdown_action = ""
	_scene_cleanup_queued = false
	_shutting_down = false
	_battle_flow_coordinator.initialize_battle_context(
		_app_runtime,
		_battle_context,
		_session_adapter,
		battle_bootstrap,
		presentation_bridge,
		battle_hud,
		battle_camera_controller,
		map_theme_environment_controller,
		map_root,
		not _requires_dedicated_authority_opening()
	)
	_battle_visuals_released = not _requires_dedicated_authority_opening()
	_set_battle_visuals_available(_battle_visuals_released)
	call_deferred("_apply_battle_metadata")
	# LegacyMigration: Consume resume payload if present
	if _app_runtime != null and _app_runtime.current_resume_snapshot != null:
		battle_hud.match_message_panel.apply_message("Resumed active match")


func _requires_dedicated_authority_opening() -> bool:
	var config: BattleStartConfig = null
	if _battle_context != null and _battle_context.battle_start_config != null:
		config = _battle_context.battle_start_config
	elif _app_runtime != null and _app_runtime.current_start_config != null:
		config = _app_runtime.current_start_config
	if config == null:
		return false
	return String(config.topology) == "dedicated_server" and String(config.session_mode) == "network_client"


func _release_dedicated_authority_opening() -> void:
	_battle_visuals_released = true
	_tick_accumulator = 0.0
	_pressed_direction_stack.clear()
	_direction_tap_stack.clear()
	_last_place_pressed = false
	_place_action_latched = false
	_set_battle_visuals_available(true)
	LogFrontScript.debug(
		"%s[battle_scene] dedicated_authority_opening_released" % ONLINE_LOG_PREFIX,
		"",
		0,
		"front.battle.scene"
	)


func _set_battle_visuals_available(available: bool) -> void:
	if world_root != null:
		world_root.visible = available
	if canvas_layer != null:
		canvas_layer.visible = available


func _on_authoritative_tick_completed(context: BattleContext, tick_result: Dictionary, metrics: Dictionary) -> void:
	if _requires_dedicated_authority_opening() and not _battle_visuals_released:
		if _session_adapter == null or not _session_adapter.has_method("is_dedicated_authority_ready") or not _session_adapter.is_dedicated_authority_ready():
			return
		_release_dedicated_authority_opening()
	_battle_flow_coordinator.consume_authoritative_tick(_app_runtime, context, presentation_bridge, battle_hud, tick_result, metrics)
	_consume_battle_events(tick_result.get("events", []))


func _on_battle_finished_authoritatively(result: BattleResult) -> void:
	if _finished:
		return
	_finished = true
	var transition := _battle_result_transition_controller.on_battle_finished_authoritatively(
		_app_runtime,
		result,
		_settlement_sync_token,
		SETTLEMENT_SHOW_DELAY_SEC,
		Callable(self, "_log_online_flow")
	)
	_pending_settlement_result = transition.get("pending_settlement_result", null)
	_settlement_delay_remaining = float(transition.get("settlement_delay_remaining", 0.0))
	_settlement_sync_token = int(transition.get("settlement_sync_token", _settlement_sync_token))
	var match_id := String(transition.get("match_id", ""))
	if not match_id.is_empty():
		call_deferred("_fetch_server_settlement_summary_with_retry", match_id, _settlement_sync_token)
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
	_battle_visuals_released = false
	_set_battle_visuals_available(false)


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
	_request_post_shutdown_action("return_to_lobby" if _battle_result_transition_controller.should_return_to_lobby_after_settlement(_app_runtime) else "return_to_room")


func _on_settlement_rematch_requested() -> void:
	_request_post_shutdown_action("rematch")


func _request_post_shutdown_action(action: String) -> void:
	if not _post_shutdown_action.is_empty():
		return
	_post_shutdown_action = _battle_result_transition_controller.request_post_shutdown_action(action, _app_runtime, _post_shutdown_action, Callable(self, "_log_online_flow"))
	_shutdown_active_battle()
	if _app_runtime != null:
		_app_runtime.unregister_battle_modules(self)
	_battle_result_transition_controller.complete_post_shutdown_action(
		_post_shutdown_action,
		_app_runtime,
		_room_return_recovery,
		Callable(self, "_queue_scene_cleanup")
	)
	_post_shutdown_action = ""


func _consume_battle_events(events: Array) -> void:
	for event in events:
		if event == null:
			continue
		match int(event.event_type):
			SimEvent.EventType.PLAYER_KILLED:
				battle_hud.on_player_killed_event(event)
			SimEvent.EventType.ITEM_PICKED:
				battle_hud.on_item_picked_event(event, _battle_flow_coordinator.resolve_local_player_entity_id(_app_runtime, _battle_context))
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
	var direction := _resolve_current_direction()
	if not direction.is_empty():
		match direction:
			"left":
				move_x = -1
			"right":
				move_x = 1
			"up":
				move_y = -1
			"down":
				move_y = 1
	var place_pressed := Input.is_key_pressed(KEY_SPACE)
	var place_just_pressed := _place_action_latched or (place_pressed and not _last_place_pressed)
	_place_action_latched = false
	_last_place_pressed = place_pressed
	return {
		"move_x": move_x,
		"move_y": move_y,
		"action_bits": PlayerInputFrame.BIT_PLACE if place_just_pressed else 0,
	}


func _resolve_current_direction() -> String:
	_prune_released_directions()
	if not _pressed_direction_stack.is_empty():
		return String(_pressed_direction_stack[_pressed_direction_stack.size() - 1])
	if not _direction_tap_stack.is_empty():
		var direction := String(_direction_tap_stack[_direction_tap_stack.size() - 1])
		_direction_tap_stack.clear()
		return direction
	return ""


func _prune_released_directions() -> void:
	var active_directions: Array[String] = []
	if Input.is_action_pressed("ui_left"):
		active_directions.append("left")
	if Input.is_action_pressed("ui_right"):
		active_directions.append("right")
	if Input.is_action_pressed("ui_up"):
		active_directions.append("up")
	if Input.is_action_pressed("ui_down"):
		active_directions.append("down")
	for direction in active_directions:
		if not _pressed_direction_stack.has(direction):
			_pressed_direction_stack.append(direction)
	var stale_directions: Array[String] = []
	for direction in _pressed_direction_stack:
		if not active_directions.has(String(direction)):
			stale_directions.append(String(direction))
	for direction in stale_directions:
		_pressed_direction_stack.erase(direction)


func _latch_direction_tap(direction: String) -> void:
	_direction_tap_stack.erase(direction)
	_direction_tap_stack.append(direction)


func _push_direction(direction: String) -> void:
	_pressed_direction_stack.erase(direction)
	_pressed_direction_stack.append(direction)


func _remove_direction(direction: String) -> void:
	_pressed_direction_stack.erase(direction)


func _show_pending_settlement() -> void:
	_battle_result_transition_controller.show_pending_settlement(
		_app_runtime,
		settlement_controller,
		battle_hud,
		_pending_settlement_result,
		Callable(self, "_log_online_flow")
	)
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


func _fetch_server_settlement_summary_with_retry(match_id: String, token: int) -> void:
	await _battle_result_transition_controller.fetch_server_settlement_summary_with_retry(
		self,
		_app_runtime,
		settlement_controller,
		match_id,
		token,
		Callable(self, "_get_settlement_sync_token"),
		Callable(self, "_log_online_flow"),
		SETTLEMENT_SYNC_RETRY_DELAYS_SEC
	)


func _queue_scene_cleanup() -> void:
	if _scene_cleanup_queued:
		return
	_scene_cleanup_queued = true
	call_deferred("_cleanup_detached_battle_scene")


func _cleanup_detached_battle_scene() -> void:
	if not is_instance_valid(self):
		return
	queue_free()


func _apply_battle_metadata() -> void:
	_battle_flow_coordinator.apply_battle_metadata(
		_app_runtime,
		_battle_context,
		battle_hud,
		battle_meta_panel,
		battle_meta_map_label,
		battle_meta_rule_label,
		battle_meta_match_label,
		battle_meta_character_label,
		battle_meta_bubble_label
	)


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


func _log_online_flow(event_name: String, payload: Dictionary) -> void:
	LogFrontScript.debug("%s[battle_main] %s %s" % [ONLINE_LOG_PREFIX, event_name, JSON.stringify(payload)], "", 0, "front.battle.online")


func _get_settlement_sync_token() -> int:
	return _settlement_sync_token
