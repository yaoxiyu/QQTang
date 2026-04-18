extends Node

const AppRuntimeRootScript = preload("res://app/flow/app_runtime_root.gd")
const MapSelectionCatalogScript = preload("res://content/maps/catalog/map_selection_catalog.gd")
const RoomScenePresenterScript = preload("res://app/front/room/room_scene_presenter.gd")
const RoomViewModelBuilderScript = preload("res://app/front/room/room_view_model_builder.gd")
const LogFrontScript = preload("res://app/logging/log_front.gd")
const RoomSceneEventRouterScript = preload("res://scenes/front/room_scene_event_router.gd")
const RoomSceneViewBinderScript = preload("res://scenes/front/room_scene_view_binder.gd")
const RoomSceneMemberListPresenterScript = preload("res://scenes/front/room_scene_member_list_presenter.gd")
const RoomSceneSelectorPresenterScript = preload("res://scenes/front/room_scene_selector_presenter.gd")
const RoomSceneSelectionSubmitterScript = preload("res://scenes/front/room_scene_selection_submitter.gd")
const RoomSceneSnapshotCoordinatorScript = preload("res://scenes/front/room_scene_snapshot_coordinator.gd")
const ROOM_SCENE_LOG_TAG := "front.room.scene"

@onready var room_hud_controller: Node = get_node_or_null("RoomHudController")
@onready var room_root: Control = get_node_or_null("RoomRoot")
@onready var main_layout: VBoxContainer = get_node_or_null("RoomRoot/RoomScroll/MainLayout")
@onready var title_label: Label = get_node_or_null("RoomRoot/RoomScroll/MainLayout/TopBar/TitleLabel")
@onready var back_to_lobby_button: Button = get_node_or_null("RoomRoot/RoomScroll/MainLayout/TopBar/BackToLobbyButton")
@onready var room_meta_label: Label = get_node_or_null("RoomRoot/RoomScroll/MainLayout/TopBar/RoomMetaLabel")
@onready var room_kind_label: Label = get_node_or_null("RoomRoot/RoomScroll/MainLayout/SummaryCard/SummaryVBox/RoomKindLabel")
@onready var room_display_name_label: Label = get_node_or_null("RoomRoot/RoomScroll/MainLayout/SummaryCard/SummaryVBox/RoomDisplayNameLabel")
@onready var room_id_value_label: LineEdit = get_node_or_null("RoomRoot/RoomScroll/MainLayout/SummaryCard/SummaryVBox/RoomIdRow/RoomIdValueLabel")
@onready var connection_status_label: Label = get_node_or_null("RoomRoot/RoomScroll/MainLayout/SummaryCard/SummaryVBox/ConnectionStatusLabel")
@onready var auth_binding_label: Label = get_node_or_null("RoomRoot/RoomScroll/MainLayout/SummaryCard/SummaryVBox/AuthBindingLabel")
@onready var owner_label: Label = get_node_or_null("RoomRoot/RoomScroll/MainLayout/SummaryCard/SummaryVBox/OwnerLabel")
@onready var blocker_label: Label = get_node_or_null("RoomRoot/RoomScroll/MainLayout/SummaryCard/SummaryVBox/BlockerLabel")
@onready var lifecycle_status_label: Label = get_node_or_null("RoomRoot/RoomScroll/MainLayout/SummaryCard/SummaryVBox/LifecycleStatusLabel")
@onready var pending_action_status_label: Label = get_node_or_null("RoomRoot/RoomScroll/MainLayout/SummaryCard/SummaryVBox/PendingActionStatusLabel")
@onready var reconnect_window_label: Label = get_node_or_null("RoomRoot/RoomScroll/MainLayout/SummaryCard/SummaryVBox/ReconnectWindowLabel")
@onready var active_match_resume_label: Label = get_node_or_null("RoomRoot/RoomScroll/MainLayout/SummaryCard/SummaryVBox/ActiveMatchResumeLabel")
@onready var player_name_input: LineEdit = get_node_or_null("RoomRoot/RoomScroll/MainLayout/LocalLoadoutCard/LocalLoadoutVBox/PlayerNameRow/PlayerNameInput")
@onready var team_selector: OptionButton = get_node_or_null("RoomRoot/RoomScroll/MainLayout/LocalLoadoutCard/LocalLoadoutVBox/TeamRow/TeamSelector")
@onready var character_selector: OptionButton = get_node_or_null("RoomRoot/RoomScroll/MainLayout/LocalLoadoutCard/LocalLoadoutVBox/CharacterRow/CharacterSelector")
@onready var character_skin_selector: OptionButton = get_node_or_null("RoomRoot/RoomScroll/MainLayout/LocalLoadoutCard/LocalLoadoutVBox/CharacterSkinRow/CharacterSkinSelector")
@onready var bubble_selector: OptionButton = get_node_or_null("RoomRoot/RoomScroll/MainLayout/LocalLoadoutCard/LocalLoadoutVBox/BubbleRow/BubbleSelector")
@onready var bubble_skin_selector: OptionButton = get_node_or_null("RoomRoot/RoomScroll/MainLayout/LocalLoadoutCard/LocalLoadoutVBox/BubbleSkinRow/BubbleSkinSelector")
@onready var map_selector: OptionButton = get_node_or_null("RoomRoot/RoomScroll/MainLayout/RoomSelectionCard/RoomSelectionVBox/MapRow/MapSelector")
@onready var rule_value_label: Label = get_node_or_null("RoomRoot/RoomScroll/MainLayout/RoomSelectionCard/RoomSelectionVBox/RuleRow/RuleValueLabel")
@onready var game_mode_selector: OptionButton = get_node_or_null("RoomRoot/RoomScroll/MainLayout/RoomSelectionCard/RoomSelectionVBox/ModeRow/GameModeSelector")
@onready var match_format_selector: OptionButton = get_node_or_null("RoomRoot/RoomScroll/MainLayout/RoomSelectionCard/RoomSelectionVBox/MatchFormatRow/MatchFormatSelector")
@onready var match_mode_multi_select: ItemList = get_node_or_null("RoomRoot/RoomScroll/MainLayout/RoomSelectionCard/RoomSelectionVBox/MatchModeRow/MatchModeMultiSelect")
@onready var eligible_map_pool_hint_label: Label = get_node_or_null("RoomRoot/RoomScroll/MainLayout/RoomSelectionCard/RoomSelectionVBox/MatchModeRow/EligibleMapPoolHintLabel")
@onready var invite_code_value_label: LineEdit = get_node_or_null("RoomRoot/RoomScroll/MainLayout/RoomSelectionCard/RoomSelectionVBox/InviteRow/InviteCodeValueLabel")
@onready var copy_invite_code_button: Button = get_node_or_null("RoomRoot/RoomScroll/MainLayout/RoomSelectionCard/RoomSelectionVBox/InviteRow/CopyInviteCodeButton")
@onready var queue_status_label: Label = get_node_or_null("RoomRoot/RoomScroll/MainLayout/RoomSelectionCard/RoomSelectionVBox/QueueStatusRow/QueueStatusLabel")
@onready var queue_error_label: Label = get_node_or_null("RoomRoot/RoomScroll/MainLayout/RoomSelectionCard/RoomSelectionVBox/QueueStatusRow/QueueErrorLabel")
@onready var member_list: VBoxContainer = get_node_or_null("RoomRoot/RoomScroll/MainLayout/MemberCard/MemberVBox/MemberList")
@onready var map_preview_label: Label = get_node_or_null("RoomRoot/RoomScroll/MainLayout/PreviewCard/PreviewVBox/MapPreviewLabel")
@onready var rule_preview_label: Label = get_node_or_null("RoomRoot/RoomScroll/MainLayout/PreviewCard/PreviewVBox/RulePreviewLabel")
@onready var mode_preview_label: Label = get_node_or_null("RoomRoot/RoomScroll/MainLayout/PreviewCard/PreviewVBox/ModePreviewLabel")
@onready var team_preview_label: Label = get_node_or_null("RoomRoot/RoomScroll/MainLayout/PreviewCard/PreviewVBox/TeamPreviewLabel")
@onready var character_preview_label: Label = get_node_or_null("RoomRoot/RoomScroll/MainLayout/PreviewCard/PreviewVBox/CharacterPreviewLabel")
@onready var character_preview_viewport = get_node_or_null("RoomRoot/RoomScroll/MainLayout/PreviewCard/PreviewVBox/CharacterPreviewViewport")
@onready var character_skin_preview_label: Label = get_node_or_null("RoomRoot/RoomScroll/MainLayout/PreviewCard/PreviewVBox/CharacterSkinPreviewLabel")
@onready var character_skin_icon: TextureRect = get_node_or_null("RoomRoot/RoomScroll/MainLayout/PreviewCard/PreviewVBox/CharacterSkinIcon")
@onready var bubble_preview_label: Label = get_node_or_null("RoomRoot/RoomScroll/MainLayout/PreviewCard/PreviewVBox/BubblePreviewLabel")
@onready var bubble_skin_preview_label: Label = get_node_or_null("RoomRoot/RoomScroll/MainLayout/PreviewCard/PreviewVBox/BubbleSkinPreviewLabel")
@onready var bubble_skin_icon: TextureRect = get_node_or_null("RoomRoot/RoomScroll/MainLayout/PreviewCard/PreviewVBox/BubbleSkinIcon")
@onready var leave_room_button: Button = get_node_or_null("RoomRoot/RoomScroll/MainLayout/ActionRow/LeaveRoomButton")
@onready var ready_button: Button = get_node_or_null("RoomRoot/RoomScroll/MainLayout/ActionRow/ReadyButton")
@onready var start_button: Button = get_node_or_null("RoomRoot/RoomScroll/MainLayout/ActionRow/StartButton")
@onready var enter_queue_button: Button = get_node_or_null("RoomRoot/RoomScroll/MainLayout/ActionRow/EnterQueueButton")
@onready var cancel_queue_button: Button = get_node_or_null("RoomRoot/RoomScroll/MainLayout/ActionRow/CancelQueueButton")
@onready var add_opponent_button: Button = get_node_or_null("RoomRoot/RoomScroll/MainLayout/ActionRow/AddOpponentButton")
@onready var room_debug_panel: PanelContainer = get_node_or_null("RoomRoot/RoomScroll/MainLayout/RoomDebugPanel")
@onready var debug_label: Label = get_node_or_null("RoomRoot/RoomScroll/MainLayout/RoomDebugPanel/DebugLabel")
@onready var battle_allocation_label: Label = get_node_or_null("RoomRoot/RoomScroll/MainLayout/SummaryCard/SummaryVBox/BattleAllocationLabel")

var _app_runtime: Node = null
var _room_controller: Node = null
var _front_flow: Node = null
var _room_use_case: RoomUseCase = null
var _room_scene_presenter: RoomScenePresenter = RoomScenePresenterScript.new()
var _room_view_model_builder: RoomViewModelBuilder = RoomViewModelBuilderScript.new()
var _room_scene_event_router: RefCounted = RoomSceneEventRouterScript.new()
var _room_scene_view_binder: RefCounted = RoomSceneViewBinderScript.new()
var _room_scene_member_list_presenter: RefCounted = RoomSceneMemberListPresenterScript.new()
var _room_scene_selector_presenter: RefCounted = RoomSceneSelectorPresenterScript.new()
var _room_scene_selection_submitter: RefCounted = RoomSceneSelectionSubmitterScript.new()
var _room_scene_snapshot_coordinator: RefCounted = RoomSceneSnapshotCoordinatorScript.new()
var _suppress_selection_callbacks: bool = false


func _ready() -> void:
	_populate_selectors()
	_connect_ui_signals()
	_bind_runtime()


func _bind_runtime() -> void:
	_app_runtime = AppRuntimeRootScript.get_existing(get_tree())
	if _app_runtime == null:
		_redirect_to_boot_if_missing()
		return
	if _app_runtime.has_method("is_runtime_ready") and _app_runtime.is_runtime_ready():
		_on_runtime_ready()
		return
	if _app_runtime.has_signal("runtime_ready") and not _app_runtime.runtime_ready.is_connected(_on_runtime_ready):
		_app_runtime.runtime_ready.connect(_on_runtime_ready, CONNECT_ONE_SHOT)


func _on_runtime_ready() -> void:
	_room_controller = _app_runtime.room_session_controller
	_front_flow = _app_runtime.front_flow
	_room_use_case = _app_runtime.room_use_case
	_connect_runtime_signals()
	_apply_local_profile_defaults()
	if _room_controller != null and _room_controller.has_method("build_room_snapshot"):
		_refresh_room(_room_controller.build_room_snapshot())
	_try_consume_pending_room_action()


func _redirect_to_boot_if_missing() -> void:
	_set_room_feedback("Runtime missing, returning to boot...")
	if _app_runtime != null and _app_runtime.front_flow != null and _app_runtime.front_flow.has_method("enter_boot"):
		_app_runtime.front_flow.enter_boot()
		return
	get_tree().change_scene_to_file("res://scenes/front/boot_scene.tscn")


func _exit_tree() -> void:
	if _room_controller != null:
		if _room_controller.room_snapshot_changed.is_connected(_on_room_snapshot_changed):
			_room_controller.room_snapshot_changed.disconnect(_on_room_snapshot_changed)
		if _room_controller.start_match_requested.is_connected(_on_start_match_requested):
			_room_controller.start_match_requested.disconnect(_on_start_match_requested)


func _populate_selectors() -> void:
	_room_scene_selector_presenter.populate_selectors(self)


func _populate_character_selector() -> void:
	_room_scene_selector_presenter.populate_character_selector(self)


func _populate_team_selector(team_option_max: int = 2) -> void:
	_room_scene_selector_presenter.populate_team_selector(self, team_option_max)


func _populate_character_skin_selector() -> void:
	_room_scene_selector_presenter.populate_character_skin_selector(self)


func _populate_bubble_selector() -> void:
	_room_scene_selector_presenter.populate_bubble_selector(self)


func _populate_bubble_skin_selector() -> void:
	_room_scene_selector_presenter.populate_bubble_skin_selector(self)


func _populate_map_selector(mode_id: String = "") -> void:
	_room_scene_selector_presenter.populate_map_selector(self, mode_id)


func _populate_mode_selector() -> void:
	_room_scene_selector_presenter.populate_mode_selector(self)


func _populate_match_format_selector(queue_type: String) -> void:
	_room_scene_selector_presenter.populate_match_format_selector(self, queue_type)


func _populate_match_mode_multi_select(queue_type: String, match_format_id: String, selected_mode_ids: Array[String] = []) -> void:
	_room_scene_selector_presenter.populate_match_mode_multi_select(self, queue_type, match_format_id, selected_mode_ids)


func _connect_ui_signals() -> void:
	if _room_scene_event_router == null:
		return
	_room_scene_event_router.connect_ui_signals(self)


func _connect_runtime_signals() -> void:
	if _room_controller == null:
		return
	if not _room_controller.room_snapshot_changed.is_connected(_on_room_snapshot_changed):
		_room_controller.room_snapshot_changed.connect(_on_room_snapshot_changed)
	if not _room_controller.start_match_requested.is_connected(_on_start_match_requested):
		_room_controller.start_match_requested.connect(_on_start_match_requested)


func _apply_local_profile_defaults() -> void:
	_room_scene_selection_submitter.apply_local_profile_defaults(self)


func _refresh_room(snapshot: RoomSnapshot) -> void:
	_room_scene_snapshot_coordinator.refresh_room(self, snapshot)


func _update_preview(snapshot: RoomSnapshot) -> void:
	_room_scene_snapshot_coordinator.update_preview(self, snapshot)


func _update_auth_binding_summary(snapshot: RoomSnapshot) -> void:
	_room_scene_snapshot_coordinator.update_auth_binding_summary(self, snapshot)


func _update_debug_text(snapshot: RoomSnapshot, view_model: Dictionary) -> void:
	_room_scene_snapshot_coordinator.update_debug_text(self, snapshot, view_model)


func _apply_room_kind_visibility(view_model: Dictionary) -> void:
	_room_scene_snapshot_coordinator.apply_room_kind_visibility(self, view_model)


func _refresh_match_room_controls(snapshot: RoomSnapshot, view_model: Dictionary) -> void:
	_room_scene_snapshot_coordinator.refresh_match_room_controls(self, snapshot, view_model)


func _resolve_local_member(snapshot: RoomSnapshot) -> RoomMemberState:
	return _room_scene_snapshot_coordinator.resolve_local_member(self, snapshot)


func _on_room_snapshot_changed(snapshot: RoomSnapshot) -> void:
	_room_scene_snapshot_coordinator.on_room_snapshot_changed(self, snapshot)


func _on_start_match_requested(snapshot: RoomSnapshot) -> void:
	if _app_runtime == null:
		return
	if String(snapshot.topology) == "dedicated_server":
		return
	var config: BattleStartConfig = _app_runtime.build_and_store_start_config(snapshot)
	if config == null or config.match_id.is_empty():
		if debug_label != null:
			debug_label.text = "Failed to build start config"
		return
	if _front_flow != null and _front_flow.has_method("request_start_match"):
		_front_flow.request_start_match()


func _on_back_to_lobby_pressed() -> void:
	if _room_use_case == null:
		return
	_room_use_case.leave_room()


func _on_leave_room_pressed() -> void:
	if _room_use_case == null:
		return
	_room_use_case.leave_room()


func _on_ready_button_pressed() -> void:
	if _room_use_case == null:
		return
	var result := _room_use_case.toggle_ready()
	if not bool(result.get("ok", false)):
		_set_room_feedback(String(result.get("user_message", "Failed to toggle ready")))


func _on_start_button_pressed() -> void:
	if _room_use_case == null:
		return
	var result := _room_use_case.start_match()
	if not bool(result.get("ok", false)):
		_set_room_feedback(String(result.get("user_message", "Failed to start match")))


func _on_enter_queue_button_pressed() -> void:
	_log_room("enter_queue_button_pressed", {})
	if _room_use_case == null:
		_log_room("enter_queue_button_pressed_no_use_case", {})
		return
	var result := _room_use_case.enter_match_queue()
	_log_room("enter_queue_result", result)
	if not bool(result.get("ok", false)):
		_set_room_feedback(String(result.get("user_message", "Failed to enter queue")))


func _on_cancel_queue_button_pressed() -> void:
	if _room_use_case == null:
		return
	var result := _room_use_case.cancel_match_queue()
	if not bool(result.get("ok", false)):
		_set_room_feedback(String(result.get("user_message", "Failed to cancel queue")))


func _on_copy_invite_code_button_pressed() -> void:
	if invite_code_value_label == null:
		return
	DisplayServer.clipboard_set(invite_code_value_label.text)
	_set_room_feedback("Invite code copied")


func _on_add_opponent_pressed() -> void:
	if _app_runtime == null or _room_controller == null or _app_runtime.debug_tools == null:
		_set_room_feedback("Practice opponent helper is unavailable")
		return
	if not _app_runtime.debug_tools.has_method("ensure_manual_local_loop_room"):
		_set_room_feedback("Practice opponent helper is unavailable")
		return
	_app_runtime.debug_tools.ensure_manual_local_loop_room(
		_room_controller,
		int(_app_runtime.local_peer_id),
		int(_app_runtime.remote_peer_id),
		_selected_metadata(map_selector),
		String(_resolve_map_binding(_selected_metadata(map_selector)).get("bound_rule_set_id", ""))
	)
	_set_room_feedback("")


func _on_profile_changed() -> void:
	_room_scene_selection_submitter.on_profile_changed(self)


func _on_profile_selector_changed() -> void:
	_room_scene_selection_submitter.on_profile_selector_changed(self)


func _on_mode_selection_changed() -> void:
	_room_scene_selection_submitter.on_mode_selection_changed(self)


func _on_selection_changed() -> void:
	_room_scene_selection_submitter.on_selection_changed(self)


func _on_match_format_changed() -> void:
	_room_scene_selection_submitter.on_match_format_changed(self)


func _on_match_mode_multi_select_changed() -> void:
	_room_scene_selection_submitter.on_match_mode_multi_select_changed(self)


func _set_room_feedback(message: String) -> void:
	if _room_scene_view_binder == null:
		return
	_room_scene_view_binder.set_room_feedback(self, message)


func _selected_metadata(selector: OptionButton) -> String:
	return _room_scene_selector_presenter.selected_metadata(selector)


func _select_metadata(selector: OptionButton, value: String) -> void:
	_room_scene_selector_presenter.select_metadata(selector, value)


func _selected_team_id() -> int:
	return _room_scene_selector_presenter.selected_team_id(self)


func _select_team_id(team_id: int) -> void:
	_room_scene_selector_presenter.select_team_id(self, team_id)


func _selected_match_mode_ids() -> Array[String]:
	return _room_scene_selector_presenter.selected_match_mode_ids(self)


func _update_eligible_map_pool_hint(queue_type: String, match_format_id: String) -> void:
	_room_scene_selector_presenter.update_eligible_map_pool_hint(self, queue_type, match_format_id)


func _resolve_map_binding(map_id: String) -> Dictionary:
	if map_id.is_empty():
		return {}
	var binding := MapSelectionCatalogScript.get_map_binding(map_id)
	if binding.is_empty() or not bool(binding.get("valid", false)):
		return {}
	return binding


func _log_room(event_name: String, payload: Dictionary) -> void:
	LogFrontScript.debug("[room_scene] %s %s" % [event_name, JSON.stringify(payload)], "", 0, ROOM_SCENE_LOG_TAG)


func _try_consume_pending_room_action() -> void:
	if _app_runtime == null:
		return
	var pending_action := String(_app_runtime.pending_room_action)
	if _app_runtime.room_session_controller != null and _app_runtime.room_session_controller.has_method("set_pending_room_action"):
		_app_runtime.room_session_controller.set_pending_room_action(pending_action)
	if pending_action != "rematch":
		return
	var snapshot: RoomSnapshot = _room_controller.build_room_snapshot() if _room_controller != null and _room_controller.has_method("build_room_snapshot") else null
	if snapshot == null:
		_app_runtime.pending_room_action = ""
		if _app_runtime.room_session_controller != null and _app_runtime.room_session_controller.has_method("set_pending_room_action"):
			_app_runtime.room_session_controller.set_pending_room_action("")
		return
	var entry_context = _app_runtime.current_room_entry_context
	if entry_context == null or String(entry_context.topology) != "dedicated_server":
		_app_runtime.pending_room_action = ""
		if _app_runtime.room_session_controller != null and _app_runtime.room_session_controller.has_method("set_pending_room_action"):
			_app_runtime.room_session_controller.set_pending_room_action("")
		return
	if _app_runtime.local_peer_id == snapshot.owner_peer_id:
		var result := _room_use_case.request_rematch()
		if bool(result.get("ok", false)):
			_set_room_feedback("Rematch requested...")
		else:
			_set_room_feedback(String(result.get("user_message", "Rematch failed")))
	else:
		_set_room_feedback("Waiting host to rematch...")
	_app_runtime.pending_room_action = ""
	if _app_runtime.room_session_controller != null and _app_runtime.room_session_controller.has_method("set_pending_room_action"):
		_app_runtime.room_session_controller.set_pending_room_action("")
