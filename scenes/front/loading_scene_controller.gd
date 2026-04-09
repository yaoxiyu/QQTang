extends Node

const AppRuntimeRootScript = preload("res://app/flow/app_runtime_root.gd")
const FrontFlowControllerScript = preload("res://app/flow/front_flow_controller.gd")

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

var _app_runtime: Node = null
var _front_flow: Node = null
var _room_client_gateway: RefCounted = null
var _local_prepare_completed: bool = false
var _transition_handled: bool = false


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
	if _app_runtime.loading_use_case != null and _app_runtime.loading_use_case.has_method("begin_loading"):
		_app_runtime.loading_use_case.begin_loading()
	_restore_missing_start_config_from_adapter()
	_refresh_loading_view()
	call_deferred("_complete_local_prepare")


func _redirect_to_boot_if_missing() -> void:
	get_tree().change_scene_to_file("res://scenes/front/boot_scene.tscn")


func _configure_layout() -> void:
	loading_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_layout.anchor_right = 1.0
	main_layout.anchor_bottom = 1.0
	main_layout.offset_left = 64.0
	main_layout.offset_top = 64.0
	main_layout.offset_right = -64.0
	main_layout.offset_bottom = -64.0
	main_layout.add_theme_constant_override("separation", 18)
	player_loading_list.add_theme_constant_override("separation", 8)
	loading_label.text = "Loading Match..."
	player_loadout_title_label.text = "Players"
	timeout_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	timeout_hint.text = "Preparing runtime..."
	if loading_phase_label != null:
		loading_phase_label.text = "Phase: initializing"
	if loading_status_label != null:
		loading_status_label.text = "Preparing..."


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
	loading_status_label.text = String(view_state.waiting_summary_text)
	timeout_hint.text = String(view_state.status_message)
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
