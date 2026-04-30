extends Node

const AppRuntimeRootScript = preload("res://app/flow/app_runtime_root.gd")
const FrontFlowControllerScript = preload("res://app/flow/front_flow_controller.gd")
const BattleEntryUseCaseScript = preload("res://app/front/battle/battle_entry_use_case.gd")
const LogFrontScript = preload("res://app/logging/log_front.gd")
const BATTLE_ENTRY_LOG_PREFIX := "[QQT_BATTLE_ENTRY]"
const BATTLE_ENTRY_ACK_TIMEOUT_SEC := 3.0

@onready var loading_root: Control = $LoadingRoot
@onready var main_layout: VBoxContainer = $LoadingRoot/MainLayout
@onready var loading_label: Label = $LoadingRoot/MainLayout/LoadingLabel
@onready var manifest_summary_panel: PanelContainer = $LoadingRoot/MainLayout/ManifestSummaryPanel
@onready var map_summary_label: Label = $LoadingRoot/MainLayout/ManifestSummaryPanel/SummaryVBox/MapSummaryLabel
@onready var rule_summary_label: Label = $LoadingRoot/MainLayout/ManifestSummaryPanel/SummaryVBox/RuleSummaryLabel
@onready var mode_summary_label: Label = $LoadingRoot/MainLayout/ManifestSummaryPanel/SummaryVBox/ModeSummaryLabel
@onready var item_summary_label: Label = $LoadingRoot/MainLayout/ManifestSummaryPanel/SummaryVBox/ItemSummaryLabel
@onready var character_summary_label: Label = $LoadingRoot/MainLayout/ManifestSummaryPanel/SummaryVBox/CharacterSummaryLabel
@onready var bubble_summary_label: Label = $LoadingRoot/MainLayout/ManifestSummaryPanel/SummaryVBox/BubbleSummaryLabel
@onready var player_loadout_title_label: Label = $LoadingRoot/MainLayout/PlayerLoadoutTitleLabel
@onready var player_loading_list: VBoxContainer = $LoadingRoot/MainLayout/PlayerLoadingList
@onready var timeout_hint: Label = $LoadingRoot/MainLayout/TimeoutHint
@onready var loading_phase_label: Label = $LoadingRoot/MainLayout/LoadingPhaseLabel
@onready var loading_status_label: Label = $LoadingRoot/MainLayout/LoadingStatusLabel
@onready var loading_mode_label: Label = get_node_or_null("LoadingRoot/MainLayout/LoadingModeLabel")
@onready var resume_hint_label: Label = get_node_or_null("LoadingRoot/MainLayout/ResumeHintLabel")

var _app_runtime: Node = null
var _front_flow: Node = null
var _room_client_gateway: RefCounted = null
var _local_prepare_completed: bool = false
var _transition_handled: bool = false
var _battle_entry_context = null
var _reference_progress_fill: ColorRect = null
var _reference_progress_label: Label = null


func _ready() -> void:
	_configure_layout()
	_bind_runtime()


func _bind_runtime() -> void:
	_app_runtime = AppRuntimeRootScript.get_existing(get_tree())
	if _app_runtime == null:
		loading_label.text = "Runtime missing. Returning to boot..."
		_redirect_to_boot_if_missing()
		return
	if _app_runtime.has_method("is_runtime_ready") and _app_runtime.is_runtime_ready():
		_on_runtime_ready()
		return
	if _app_runtime.has_signal("runtime_ready") and not _app_runtime.runtime_ready.is_connected(_on_runtime_ready):
		_app_runtime.runtime_ready.connect(_on_runtime_ready, CONNECT_ONE_SHOT)


func _on_runtime_ready() -> void:
	_front_flow = _app_runtime.front_flow
	_room_client_gateway = _app_runtime.room_use_case.get("room_client_gateway") if _app_runtime.room_use_case != null else null
	_connect_gateway_signals()

	if "current_battle_entry_context" in _app_runtime and _app_runtime.current_battle_entry_context != null:
		_battle_entry_context = _app_runtime.current_battle_entry_context
		_log_battle_entry("loading_scene_battle_entry_mode", _battle_entry_context.to_dict())
		if "current_loading_mode" in _app_runtime and String(_app_runtime.current_loading_mode) == "resume_match":
			_run_battle_resume_flow()
			return
		_run_battle_entry_flow()
		return

	if _app_runtime.loading_use_case != null and _app_runtime.loading_use_case.has_method("begin_loading"):
		_app_runtime.loading_use_case.begin_loading()
	_restore_missing_start_config_from_adapter()
	_refresh_loading_view()
	call_deferred("_complete_local_prepare")


func _redirect_to_boot_if_missing() -> void:
	get_tree().change_scene_to_file("res://scenes/front/boot_scene.tscn")


func _configure_layout() -> void:
	_ensure_loading_background()
	_build_reference_loading_layout()
	loading_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_layout.anchor_right = 1.0
	main_layout.anchor_bottom = 1.0
	main_layout.offset_left = 64.0
	main_layout.offset_top = 64.0
	main_layout.offset_right = -64.0
	main_layout.offset_bottom = -64.0
	main_layout.add_theme_constant_override("separation", 18)
	player_loading_list.add_theme_constant_override("separation", 8)
	manifest_summary_panel.add_theme_stylebox_override("panel", _make_loading_style(Color(0.12, 0.17, 0.22, 0.94), Color(0.34, 0.50, 0.66, 0.75), 8))
	manifest_summary_panel.set_meta("ui_asset_id", "ui.loading.panel.task")
	loading_label.text = "Loading Match..."
	loading_label.add_theme_font_size_override("font_size", 34)
	player_loadout_title_label.text = "Players"
	player_loadout_title_label.add_theme_font_size_override("font_size", 20)
	timeout_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	timeout_hint.text = "Preparing runtime..."
	if loading_phase_label != null:
		loading_phase_label.text = "Phase: initializing"
	if loading_status_label != null:
		loading_status_label.text = "Preparing..."
		loading_status_label.set_meta("ui_asset_id", "ui.loading.progress.fill")
	loading_root.set_meta("ui_asset_id", "ui.loading.bg.main")


func _refresh_loading_view() -> void:
	for child in player_loading_list.get_children():
		child.queue_free()
	if _app_runtime == null or _app_runtime.loading_use_case == null:
		timeout_hint.text = "Loading runtime is not available."
		return
	var view_state = _app_runtime.loading_use_case.build_view_state()
	loading_label.text = "Loading %s" % String(view_state.map_display_name)
	map_summary_label.text = "地图: %s" % String(view_state.map_display_name)
	rule_summary_label.text = "规则: %s" % String(view_state.rule_display_name)
	mode_summary_label.text = "模式: %s" % String(view_state.mode_display_name)
	item_summary_label.text = String(view_state.item_brief)
	character_summary_label.text = "角色: %s" % String(view_state.character_brief)
	bubble_summary_label.text = "泡泡: %s" % String(view_state.bubble_brief)
	loading_phase_label.text = "Phase: %s" % String(view_state.loading_phase_text)
	loading_status_label.text = "%s | %s" % [String(view_state.waiting_summary_text), String(view_state.progress_detail_text)]
	_update_reference_progress(float(view_state.progress))
	timeout_hint.text = String(view_state.status_message)
	if loading_mode_label != null:
		loading_mode_label.text = "Mode: %s" % String(view_state.loading_mode)
	if resume_hint_label != null:
		resume_hint_label.text = String(view_state.resume_hint_text)
	for line in view_state.player_lines:
		var label := Label.new()
		label.text = line
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		player_loading_list.add_child(label)


func _restore_missing_start_config_from_adapter() -> void:
	if _app_runtime == null or _app_runtime.current_start_config != null or _app_runtime.battle_session_adapter == null:
		return
	var adapter_config: BattleStartConfig = _app_runtime.battle_session_adapter.get("start_config")
	if adapter_config == null:
		return
	_app_runtime.apply_canonical_start_config(adapter_config)


func _complete_local_prepare() -> void:
	if _app_runtime == null or _app_runtime.loading_use_case == null:
		return
	await get_tree().process_frame
	_local_prepare_completed = true
	_maybe_submit_local_ready()


func _connect_gateway_signals() -> void:
	if _room_client_gateway == null:
		return
	if not _room_client_gateway.match_loading_snapshot_received.is_connected(_on_match_loading_snapshot_received):
		_room_client_gateway.match_loading_snapshot_received.connect(_on_match_loading_snapshot_received)


func _exit_tree() -> void:
	if _room_client_gateway != null and _room_client_gateway.match_loading_snapshot_received.is_connected(_on_match_loading_snapshot_received):
		_room_client_gateway.match_loading_snapshot_received.disconnect(_on_match_loading_snapshot_received)


func _on_match_loading_snapshot_received(snapshot: MatchLoadingSnapshot) -> void:
	if _app_runtime == null or _app_runtime.loading_use_case == null:
		return
	var result: Dictionary = _app_runtime.loading_use_case.consume_loading_snapshot(snapshot)
	_refresh_loading_view()
	if bool(result.get("aborted", false)):
		_handle_loading_aborted(snapshot)
		return
	if bool(result.get("committed", false)):
		_handle_loading_committed()
		return
	_maybe_submit_local_ready()


func _maybe_submit_local_ready() -> void:
	if not _local_prepare_completed or _transition_handled:
		return
	if _app_runtime == null or _app_runtime.loading_use_case == null:
		return
	
	# LegacyMigration: In resume mode, directly handle loading committed
	if "current_loading_mode" in _app_runtime and String(_app_runtime.current_loading_mode) == "resume_match":
		_handle_loading_committed()
		return
	
	_app_runtime.loading_use_case.submit_local_ready()


func _handle_loading_committed() -> void:
	if _transition_handled:
		return
	_transition_handled = true
	if _front_flow != null and _front_flow.is_in_state(FrontFlowControllerScript.FlowState.MATCH_LOADING):
		_front_flow.on_match_loading_ready(_app_runtime.current_start_config)


func _handle_loading_aborted(snapshot: MatchLoadingSnapshot) -> void:
	if _transition_handled:
		return
	_transition_handled = true
	if _app_runtime != null and _app_runtime.room_session_controller != null and _app_runtime.room_session_controller.has_method("set_last_error"):
		_app_runtime.room_session_controller.set_last_error(snapshot.error_code, snapshot.user_message, {})
	if _front_flow != null and _front_flow.has_method("enter_room"):
		_front_flow.enter_room()


## Battle entry flow: request ticket, update UI, transition to battle.
func _run_battle_entry_flow() -> void:
	if _battle_entry_context == null or _app_runtime == null:
		_set_loading_status("Battle entry context missing")
		return

	_set_loading_status("Allocating battle server...")
	loading_label.text = "Entering Battle"

	if not _battle_entry_context.is_valid():
		_log_battle_entry("battle_entry_context_invalid", _battle_entry_context.to_dict())
		_set_loading_status("Battle server not ready")
		_abort_battle_entry("BATTLE_ENTRY_INVALID", "Battle entry context is invalid")
		return

	_set_loading_status("Battle server ready: %s:%d" % [_battle_entry_context.battle_server_host, _battle_entry_context.battle_server_port])

	# Request battle ticket from account_service
	_set_loading_status("Requesting battle ticket...")
	var battle_entry_use_case = BattleEntryUseCaseScript.new()
	battle_entry_use_case.call("configure", _app_runtime)
	var ticket_result_raw = battle_entry_use_case.call("request_battle_ticket", _battle_entry_context)
	var ticket_result: Dictionary = ticket_result_raw if ticket_result_raw is Dictionary else {"ok": false, "error_code": "INVALID_RESULT", "user_message": "Invalid ticket result"}
	if not bool(ticket_result.get("ok", false)):
		_log_battle_entry("battle_ticket_failed", ticket_result)
		_set_loading_status("Battle ticket failed: %s" % String(ticket_result.get("user_message", "")))
		_abort_battle_entry(
			String(ticket_result.get("error_code", "BATTLE_TICKET_FAILED")),
			String(ticket_result.get("user_message", "Failed to acquire battle ticket"))
		)
		return

	_set_loading_status("Battle ticket acquired. Connecting to battle DS...")
	_log_battle_entry("battle_entry_ticket_acquired", {
		"ticket_id": _battle_entry_context.battle_ticket_id,
		"battle_id": _battle_entry_context.battle_id,
	})

	if _room_client_gateway == null or not _room_client_gateway.has_method("request_ack_battle_entry"):
		_abort_battle_entry("ROOM_ACK_GATEWAY_MISSING", "Room gateway cannot acknowledge battle entry")
		return
	_room_client_gateway.request_ack_battle_entry(
		String(_battle_entry_context.assignment_id),
		String(_battle_entry_context.battle_id)
	)
	var ack_result := await _wait_for_battle_entry_ack()
	if not bool(ack_result.get("ok", false)):
		_abort_battle_entry(
			String(ack_result.get("error_code", "ROOM_ACK_BATTLE_ENTRY_FAILED")),
			String(ack_result.get("user_message", "Room failed to acknowledge battle entry"))
		)
		return

	# Store battle entry context on runtime for battle scene to consume
	_app_runtime.current_battle_entry_context = _battle_entry_context

	# Transition to battle scene
	_transition_handled = true
	if _front_flow != null and _front_flow.is_in_state(FrontFlowControllerScript.FlowState.MATCH_LOADING):
		_front_flow.on_match_loading_ready(null)


func _run_battle_resume_flow() -> void:
	if _battle_entry_context == null or _app_runtime == null:
		_set_loading_status("Battle resume context missing")
		return
	loading_label.text = "Resuming Battle"
	if not _battle_entry_context.is_valid():
		_log_battle_entry("battle_resume_context_invalid", _battle_entry_context.to_dict())
		_abort_battle_entry("BATTLE_RESUME_INVALID", "Battle resume context is invalid")
		return
	_set_loading_status("Connecting to battle DS: %s:%d" % [_battle_entry_context.battle_server_host, _battle_entry_context.battle_server_port])
	_app_runtime.current_battle_entry_context = _battle_entry_context
	_transition_handled = true
	if _front_flow != null and _front_flow.is_in_state(FrontFlowControllerScript.FlowState.MATCH_LOADING):
		_front_flow.on_match_loading_ready(null)


func _wait_for_battle_entry_ack() -> Dictionary:
	if _room_client_gateway == null:
		return {"ok": false, "error_code": "ROOM_ACK_GATEWAY_MISSING", "user_message": "Room gateway cannot acknowledge battle entry"}
	if not _room_client_gateway.has_signal("room_operation_accepted") or not _room_client_gateway.has_signal("room_error"):
		return {"ok": false, "error_code": "ROOM_ACK_SIGNAL_MISSING", "user_message": "Room gateway cannot report battle entry acknowledgement"}
	var state := {
		"done": false,
		"ok": false,
		"error_code": "",
		"user_message": "",
	}
	var accepted_callback := func(operation: String, _request_id: String) -> void:
		if String(operation) != "AckBattleEntry":
			return
		state["done"] = true
		state["ok"] = true
	var error_callback := func(error_code: String, user_message: String) -> void:
		state["done"] = true
		state["ok"] = false
		state["error_code"] = error_code
		state["user_message"] = user_message
	_room_client_gateway.room_operation_accepted.connect(accepted_callback)
	_room_client_gateway.room_error.connect(error_callback)
	var deadline_msec := Time.get_ticks_msec() + int(BATTLE_ENTRY_ACK_TIMEOUT_SEC * 1000.0)
	while not bool(state.done) and Time.get_ticks_msec() < deadline_msec:
		await get_tree().process_frame
	if _room_client_gateway != null:
		if _room_client_gateway.room_operation_accepted.is_connected(accepted_callback):
			_room_client_gateway.room_operation_accepted.disconnect(accepted_callback)
		if _room_client_gateway.room_error.is_connected(error_callback):
			_room_client_gateway.room_error.disconnect(error_callback)
	if bool(state.done):
		if bool(state.ok):
			return {"ok": true}
		return {
			"ok": false,
			"error_code": String(state.error_code),
			"user_message": String(state.user_message),
		}
	return {"ok": false, "error_code": "ROOM_ACK_BATTLE_ENTRY_TIMEOUT", "user_message": "Room battle entry acknowledgement timed out"}


func _abort_battle_entry(error_code: String, user_message: String) -> void:
	_transition_handled = true
	if _app_runtime != null and _app_runtime.room_session_controller != null and _app_runtime.room_session_controller.has_method("set_last_error"):
		_app_runtime.room_session_controller.set_last_error(error_code, user_message, {})
	if _front_flow != null and _front_flow.has_method("enter_room"):
		_front_flow.enter_room()


func _set_loading_status(text: String) -> void:
	if loading_status_label != null:
		loading_status_label.text = text
	if timeout_hint != null:
		timeout_hint.text = text


func _log_battle_entry(event_name: String, payload: Dictionary) -> void:
	LogFrontScript.debug("%s[loading_scene] %s %s" % [BATTLE_ENTRY_LOG_PREFIX, event_name, JSON.stringify(payload)], "", 0, "front.loading.scene")


func _ensure_loading_background() -> void:
	var background: ColorRect = loading_root.get_node_or_null("FormalBackground")
	if background == null:
		background = ColorRect.new()
		background.name = "FormalBackground"
		loading_root.add_child(background)
		loading_root.move_child(background, 0)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.055, 0.09, 0.13, 1.0)
	background.set_meta("ui_asset_id", "ui.loading.bg.main")


func _build_reference_loading_layout() -> void:
	var existing: Control = loading_root.get_node_or_null("ReferenceLoadingLayout")
	if existing != null:
		return
	var layout := CenterContainer.new()
	layout.name = "ReferenceLoadingLayout"
	layout.set_anchors_preset(Control.PRESET_FULL_RECT)
	loading_root.add_child(layout)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 270)
	panel.add_theme_stylebox_override("panel", _make_loading_style(Color(0.68, 0.90, 1.0, 0.92), Color(0.14, 0.58, 0.86, 1.0), 8))
	panel.set_meta("ui_asset_id", "ui.loading.panel.task")
	layout.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)
	_move_loading_node(loading_label, vbox)
	if loading_label != null:
		loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		loading_label.add_theme_color_override("font_color", Color(0.05, 0.32, 0.50, 1.0))
	_move_loading_node(loading_status_label, vbox)
	_reference_progress_label = Label.new()
	_reference_progress_label.text = "0%"
	_reference_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reference_progress_label.add_theme_color_override("font_color", Color(0.06, 0.35, 0.55, 1.0))
	vbox.add_child(_reference_progress_label)

	var progress_frame := PanelContainer.new()
	progress_frame.custom_minimum_size = Vector2(480, 34)
	progress_frame.add_theme_stylebox_override("panel", _make_loading_style(Color(0.35, 0.73, 0.94, 1.0), Color(0.08, 0.45, 0.72, 1.0), 6))
	progress_frame.set_meta("ui_asset_id", "ui.loading.progress.frame")
	vbox.add_child(progress_frame)
	var progress_clip := Control.new()
	progress_clip.clip_contents = true
	progress_clip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progress_clip.size_flags_vertical = Control.SIZE_EXPAND_FILL
	progress_frame.add_child(progress_clip)
	_reference_progress_fill = ColorRect.new()
	_reference_progress_fill.color = Color(0.08, 0.86, 1.0, 0.95)
	_reference_progress_fill.set_meta("ui_asset_id", "ui.loading.progress.fill")
	progress_clip.add_child(_reference_progress_fill)

	_move_loading_node(manifest_summary_panel, vbox)
	_move_loading_node(player_loadout_title_label, vbox)
	_move_loading_node(player_loading_list, vbox)
	_move_loading_node(timeout_hint, vbox)
	if main_layout != null:
		main_layout.visible = false


func _update_reference_progress(progress: float) -> void:
	var clamped = clamp(progress, 0.0, 1.0)
	if _reference_progress_label != null:
		_reference_progress_label.text = "%d%%" % int(round(clamped * 100.0))
	if _reference_progress_fill != null:
		_reference_progress_fill.set_anchors_preset(Control.PRESET_LEFT_WIDE)
		_reference_progress_fill.offset_left = 0.0
		_reference_progress_fill.offset_top = 0.0
		_reference_progress_fill.offset_right = 480.0 * clamped
		_reference_progress_fill.offset_bottom = 28.0


func _move_loading_node(node: Node, new_parent: Node) -> void:
	if node == null or new_parent == null or node.get_parent() == new_parent:
		return
	var old_parent := node.get_parent()
	if old_parent != null:
		old_parent.remove_child(node)
	new_parent.add_child(node)


func _make_loading_style(color: Color, border_color: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border_color
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.content_margin_left = 16.0
	style.content_margin_right = 16.0
	style.content_margin_top = 14.0
	style.content_margin_bottom = 14.0
	return style
