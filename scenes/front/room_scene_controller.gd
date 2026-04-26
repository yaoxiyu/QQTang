extends Node

const AppRuntimeRootScript = preload("res://app/flow/app_runtime_root.gd")
const MapSelectionCatalogScript = preload("res://content/maps/catalog/map_selection_catalog.gd")
const CharacterCatalogScript = preload("res://content/characters/catalog/character_catalog.gd")
const RoomCharacterPreviewScene = preload("res://scenes/front/components/room_character_preview.tscn")
const RoomScenePresenterScript = preload("res://app/front/room/room_scene_presenter.gd")
const RoomViewModelBuilderScript = preload("res://app/front/room/room_view_model_builder.gd")
const LogFrontScript = preload("res://app/logging/log_front.gd")
const RoomSceneEventRouterScript = preload("res://scenes/front/room_scene_event_router.gd")
const RoomSceneViewBinderScript = preload("res://scenes/front/room_scene_view_binder.gd")
const RoomSceneMemberListPresenterScript = preload("res://scenes/front/room_scene_member_list_presenter.gd")
const RoomSceneSelectorPresenterScript = preload("res://scenes/front/room_scene_selector_presenter.gd")
const RoomSceneSelectionSubmitterScript = preload("res://scenes/front/room_scene_selection_submitter.gd")
const RoomSceneSnapshotCoordinatorScript = preload("res://scenes/front/room_scene_snapshot_coordinator.gd")
const RoomTeamPaletteScript = preload("res://app/front/room/room_team_palette.gd")
const ROOM_SCENE_LOG_TAG := "front.room.scene"
const FORMAL_ROOM_SLOT_COUNT := 8
const FORMAL_ROOM_MIN_CUSTOM_OPEN_SLOTS := 2

@onready var room_hud_controller: Node = get_node_or_null("RoomHudController")
@onready var room_root: Control = get_node_or_null("RoomRoot")
@onready var room_scroll: ScrollContainer = get_node_or_null("RoomRoot/RoomScroll")
@onready var main_layout: VBoxContainer = get_node_or_null("RoomRoot/RoomScroll/MainLayout")
@onready var top_bar: HBoxContainer = get_node_or_null("RoomRoot/RoomScroll/MainLayout/TopBar")
@onready var title_label: Label = get_node_or_null("RoomRoot/RoomScroll/MainLayout/TopBar/TitleLabel")
@onready var back_to_lobby_button: Button = get_node_or_null("RoomRoot/RoomScroll/MainLayout/TopBar/BackToLobbyButton")
@onready var room_meta_label: Label = get_node_or_null("RoomRoot/RoomScroll/MainLayout/TopBar/RoomMetaLabel")
@onready var summary_card: PanelContainer = get_node_or_null("RoomRoot/RoomScroll/MainLayout/SummaryCard")
@onready var local_loadout_card: PanelContainer = get_node_or_null("RoomRoot/RoomScroll/MainLayout/LocalLoadoutCard")
@onready var room_selection_card: PanelContainer = get_node_or_null("RoomRoot/RoomScroll/MainLayout/RoomSelectionCard")
@onready var member_card: PanelContainer = get_node_or_null("RoomRoot/RoomScroll/MainLayout/MemberCard")
@onready var preview_card: PanelContainer = get_node_or_null("RoomRoot/RoomScroll/MainLayout/PreviewCard")
@onready var action_row: HBoxContainer = get_node_or_null("RoomRoot/RoomScroll/MainLayout/ActionRow")
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
var _formal_slot_grid: GridContainer = null
var _formal_chat_log: Label = null
var _formal_room_name_label: Label = null
var _formal_room_mode_label: Label = null
var _formal_room_map_label: Label = null
var _formal_room_member_label: Label = null
var _formal_map_preview_label: Label = null
var _formal_choose_mode_button: Button = null
var _formal_room_property_button: Button = null
var _formal_choose_map_button: Button = null
var _formal_character_grid: GridContainer = null
var _formal_team_row: HBoxContainer = null
var _formal_feedback_label: Label = null
var _formal_mode_popup: PopupPanel = null
var _formal_mode_popup_content: VBoxContainer = null
var _formal_property_popup: PopupPanel = null
var _formal_property_name_input: LineEdit = null
var _formal_map_popup: PopupPanel = null
var _formal_map_popup_content: VBoxContainer = null
var _formal_custom_open_slots: int = FORMAL_ROOM_SLOT_COUNT
var _formal_closed_slots: Dictionary = {}
var _formal_character_page: int = 0
var _formal_character_page_label: Label = null
var _formal_character_prev_button: Button = null
var _formal_character_next_button: Button = null
var _formal_profile_popup: PopupPanel = null
var _formal_profile_popup_content: VBoxContainer = null
var _formal_display_mode: String = "竞技模式"
var _last_room_snapshot: RoomSnapshot = null
var _last_room_view_model: Dictionary = {}


func _ready() -> void:
	_apply_formal_room_layout()
	_bind_runtime()
	_populate_selectors()
	_connect_ui_signals()


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
	_populate_selectors()
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
	if _room_use_case != null and _room_use_case.room_client_gateway != null and _room_use_case.room_client_gateway.room_snapshot_received.is_connected(_on_gateway_room_snapshot_received):
		_room_use_case.room_client_gateway.room_snapshot_received.disconnect(_on_gateway_room_snapshot_received)


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
	if _room_use_case != null and _room_use_case.room_client_gateway != null and not _room_use_case.room_client_gateway.room_snapshot_received.is_connected(_on_gateway_room_snapshot_received):
		_room_use_case.room_client_gateway.room_snapshot_received.connect(_on_gateway_room_snapshot_received)


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


func _on_gateway_room_snapshot_received(_snapshot: RoomSnapshot) -> void:
	if _room_controller == null or not _room_controller.has_method("build_room_snapshot"):
		return
	call_deferred("_force_refresh_current_room_view")


func _force_refresh_current_room_view() -> void:
	if _room_controller == null or _room_view_model_builder == null or _app_runtime == null:
		return
	var snapshot: RoomSnapshot = _room_controller.build_room_snapshot()
	var view_model: Dictionary = _room_view_model_builder.build_view_model(
		snapshot,
		_room_controller.room_runtime_context if _room_controller != null else null,
		_app_runtime.player_profile_state,
		_app_runtime.current_room_entry_context
	)
	if _room_scene_presenter != null:
		_room_scene_presenter.present(view_model, self)
	if _room_scene_member_list_presenter != null:
		_room_scene_member_list_presenter.present(view_model.get("members", []), member_list)
	_refresh_reference_room_panels(snapshot, view_model)


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
	_log_room("ready_button_result", result)
	if not bool(result.get("ok", false)):
		_set_room_feedback(String(result.get("user_message", "Failed to toggle ready")))


func _on_start_button_pressed() -> void:
	if _room_use_case == null:
		return
	var result := _room_use_case.start_match()
	if not bool(result.get("ok", false)):
		var message := String(result.get("user_message", "Failed to start match"))
		_set_room_feedback(message)
		return


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
	if _formal_feedback_label != null:
		_formal_feedback_label.text = message
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


func _apply_formal_room_layout() -> void:
	_ensure_room_background()
	_build_reference_room_layout()
	if room_scroll != null:
		room_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	if main_layout != null:
		main_layout.custom_minimum_size = Vector2(860, 0)
		main_layout.add_theme_constant_override("separation", 14)
	if top_bar != null:
		top_bar.add_theme_constant_override("separation", 12)
	if title_label != null:
		title_label.text = "Room"
		title_label.add_theme_font_size_override("font_size", 28)
	if room_meta_label != null:
		room_meta_label.add_theme_font_size_override("font_size", 16)
	for card in [summary_card, local_loadout_card, room_selection_card, member_card, preview_card]:
		_apply_room_card_style(card)
	for button in [back_to_lobby_button, leave_room_button, ready_button, start_button, enter_queue_button, cancel_queue_button, add_opponent_button, copy_invite_code_button]:
		_apply_room_button_style(button)
	for input in [room_id_value_label, player_name_input, invite_code_value_label]:
		_apply_room_input_style(input)
	for selector in [team_selector, character_selector, character_skin_selector, bubble_selector, bubble_skin_selector, map_selector, game_mode_selector, match_format_selector]:
		if selector != null:
			selector.custom_minimum_size = Vector2(max(selector.custom_minimum_size.x, 220.0), 38.0)
			selector.set_meta("ui_asset_id", "ui.room.panel.config")
	if room_debug_panel != null:
		room_debug_panel.visible = false
	_apply_room_asset_ids()


func _build_reference_room_layout() -> void:
	if room_root == null:
		return
	var existing: Control = room_root.get_node_or_null("ReferenceRoomLayout")
	if existing != null:
		return
	var layout := VBoxContainer.new()
	layout.name = "ReferenceRoomLayout"
	layout.set_anchors_preset(Control.PRESET_FULL_RECT)
	layout.offset_left = 10.0
	layout.offset_top = 8.0
	layout.offset_right = -10.0
	layout.offset_bottom = -8.0
	layout.add_theme_constant_override("separation", 6)
	room_root.add_child(layout)

	var reference_top_bar := HBoxContainer.new()
	reference_top_bar.custom_minimum_size = Vector2(0, 28)
	reference_top_bar.add_theme_constant_override("separation", 10)
	layout.add_child(reference_top_bar)
	_move_node_to(title_label, reference_top_bar)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reference_top_bar.add_child(spacer)
	_move_node_to(room_meta_label, reference_top_bar)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 8)
	layout.add_child(body)

	var left_panel := VBoxContainer.new()
	left_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_panel.add_theme_constant_override("separation", 6)
	body.add_child(left_panel)

	var slots_panel := PanelContainer.new()
	slots_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	slots_panel.add_theme_stylebox_override("panel", _make_room_style(Color(0.50, 0.60, 0.61, 0.92), Color(0.11, 0.62, 0.78, 1.0), 8))
	slots_panel.set_meta("ui_asset_id", "ui.room.panel.player_slots")
	left_panel.add_child(slots_panel)
	_formal_slot_grid = GridContainer.new()
	_formal_slot_grid.columns = 4
	_formal_slot_grid.custom_minimum_size = Vector2(0, 292)
	_formal_slot_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_formal_slot_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_formal_slot_grid.add_theme_constant_override("h_separation", 12)
	_formal_slot_grid.add_theme_constant_override("v_separation", 12)
	slots_panel.add_child(_formal_slot_grid)

	var chat_panel := PanelContainer.new()
	chat_panel.custom_minimum_size = Vector2(0, 118)
	chat_panel.add_theme_stylebox_override("panel", _make_room_style(Color(0.08, 0.11, 0.13, 0.96), Color(0.12, 0.58, 0.82, 1.0), 8))
	chat_panel.set_meta("ui_asset_id", "ui.room.panel.chat")
	left_panel.add_child(chat_panel)
	var chat_vbox := VBoxContainer.new()
	chat_vbox.add_theme_constant_override("separation", 5)
	chat_panel.add_child(chat_vbox)
	var chat_title := Label.new()
	chat_title.text = "房间聊天"
	chat_vbox.add_child(chat_title)
	_formal_chat_log = Label.new()
	_formal_chat_log.text = "房间聊天频道待接入"
	_formal_chat_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chat_vbox.add_child(_formal_chat_log)

	var right_panel := VBoxContainer.new()
	right_panel.custom_minimum_size = Vector2(340, 0)
	right_panel.add_theme_constant_override("separation", 6)
	body.add_child(right_panel)

	var property_panel := PanelContainer.new()
	property_panel.add_theme_stylebox_override("panel", _make_room_style(Color(0.60, 0.88, 0.92, 0.96), Color(0.11, 0.62, 0.78, 1.0), 8))
	property_panel.set_meta("ui_asset_id", "ui.room.panel.properties")
	right_panel.add_child(property_panel)
	var property_vbox := VBoxContainer.new()
	property_vbox.add_theme_constant_override("separation", 5)
	property_panel.add_child(property_vbox)
	var property_actions := HBoxContainer.new()
	property_actions.add_theme_constant_override("separation", 8)
	property_vbox.add_child(property_actions)
	_formal_choose_mode_button = _create_formal_room_button("选择模式", _on_formal_choose_mode_pressed)
	property_actions.add_child(_formal_choose_mode_button)
	_formal_room_property_button = _create_formal_room_button("房间属性", _on_formal_room_property_pressed)
	property_actions.add_child(_formal_room_property_button)
	_formal_choose_map_button = _create_formal_room_button("选择地图", _on_formal_choose_map_pressed)
	property_vbox.add_child(_formal_choose_map_button)
	_formal_map_preview_label = Label.new()
	_formal_map_preview_label.text = "随机地图"
	_formal_map_preview_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_formal_map_preview_label.custom_minimum_size = Vector2(0, 48)
	_formal_map_preview_label.add_theme_font_size_override("font_size", 18)
	property_vbox.add_child(_formal_map_preview_label)
	_formal_room_name_label = Label.new()
	property_vbox.add_child(_formal_room_name_label)
	_formal_room_mode_label = Label.new()
	property_vbox.add_child(_formal_room_mode_label)
	_formal_room_map_label = Label.new()
	property_vbox.add_child(_formal_room_map_label)
	_formal_room_member_label = Label.new()
	property_vbox.add_child(_formal_room_member_label)

	var loadout_panel := PanelContainer.new()
	loadout_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	loadout_panel.add_theme_stylebox_override("panel", _make_room_style(Color(0.60, 0.88, 0.92, 0.96), Color(0.11, 0.62, 0.78, 1.0), 8))
	loadout_panel.set_meta("ui_asset_id", "ui.room.panel.loadout_preview")
	right_panel.add_child(loadout_panel)
	var loadout_vbox := VBoxContainer.new()
	loadout_vbox.add_theme_constant_override("separation", 5)
	loadout_panel.add_child(loadout_vbox)
	var character_title := Label.new()
	character_title.text = "角色选择"
	loadout_vbox.add_child(character_title)
	_formal_character_grid = GridContainer.new()
	_formal_character_grid.columns = 4
	_formal_character_grid.custom_minimum_size = Vector2(0, 160)
	_formal_character_grid.add_theme_constant_override("h_separation", 6)
	_formal_character_grid.add_theme_constant_override("v_separation", 6)
	loadout_vbox.add_child(_formal_character_grid)
	var character_pager := HBoxContainer.new()
	character_pager.add_theme_constant_override("separation", 6)
	loadout_vbox.add_child(character_pager)
	_formal_character_page_label = Label.new()
	_formal_character_page_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	character_pager.add_child(_formal_character_page_label)
	_formal_character_prev_button = _create_formal_room_button("<", Callable(self, "_change_formal_character_page").bind(-1))
	_formal_character_prev_button.custom_minimum_size = Vector2(42, 28)
	_apply_room_small_button_style(_formal_character_prev_button)
	character_pager.add_child(_formal_character_prev_button)
	_formal_character_next_button = _create_formal_room_button(">", Callable(self, "_change_formal_character_page").bind(1))
	_formal_character_next_button.custom_minimum_size = Vector2(42, 28)
	_apply_room_small_button_style(_formal_character_next_button)
	character_pager.add_child(_formal_character_next_button)
	var team_title := Label.new()
	team_title.text = "队伍选择"
	loadout_vbox.add_child(team_title)
	_formal_team_row = HBoxContainer.new()
	_formal_team_row.add_theme_constant_override("separation", 4)
	loadout_vbox.add_child(_formal_team_row)
	_build_formal_character_buttons()
	_build_formal_team_buttons()

	var bottom_bar := HBoxContainer.new()
	bottom_bar.custom_minimum_size = Vector2(0, 46)
	bottom_bar.add_theme_constant_override("separation", 8)
	layout.add_child(bottom_bar)
	_formal_feedback_label = Label.new()
	_formal_feedback_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_formal_feedback_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bottom_bar.add_child(_formal_feedback_label)
	_move_node_to(action_row, bottom_bar)
	if action_row != null:
		action_row.alignment = BoxContainer.ALIGNMENT_END
		action_row.size_flags_horizontal = Control.SIZE_SHRINK_END
	_move_node_to(leave_room_button, action_row)
	_move_node_to(ready_button, action_row)
	_move_node_to(start_button, action_row)
	_move_node_to(enter_queue_button, action_row)
	_move_node_to(cancel_queue_button, action_row)
	if add_opponent_button != null:
		add_opponent_button.visible = false
	if back_to_lobby_button != null:
		back_to_lobby_button.visible = false
	for legacy_card in [summary_card, local_loadout_card, room_selection_card, member_card, preview_card]:
		if legacy_card != null:
			legacy_card.visible = false
	if main_layout != null:
		main_layout.visible = false
	_ensure_formal_room_popups()


func _move_node_to(node: Node, new_parent: Node) -> void:
	if node == null or new_parent == null or node.get_parent() == new_parent:
		return
	var old_parent := node.get_parent()
	if old_parent != null:
		old_parent.remove_child(node)
	new_parent.add_child(node)


func _create_formal_room_button(label_text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = label_text
	button.custom_minimum_size = Vector2(112, 42)
	_apply_room_button_style(button)
	button.pressed.connect(callback)
	return button


func _build_formal_character_buttons() -> void:
	if _formal_character_grid == null:
		return
	for child in _formal_character_grid.get_children():
		child.queue_free()
	var entries := CharacterCatalogScript.get_character_entries()
	var max_page := _get_formal_character_max_page(entries.size())
	_formal_character_page = clampi(_formal_character_page, 0, max_page)
	var start_index := _formal_character_page * 8
	for slot_index in range(8):
		var entry_index := start_index + slot_index
		if entry_index >= entries.size():
			_formal_character_grid.add_child(_create_formal_character_placeholder())
			continue
		var entry: Dictionary = entries[entry_index]
		var character_id := String(entry.get("id", ""))
		if character_id.is_empty():
			_formal_character_grid.add_child(_create_formal_character_placeholder())
			continue
		var button := Button.new()
		button.text = ""
		button.custom_minimum_size = Vector2(72, 72)
		button.toggle_mode = true
		button.set_meta("character_id", character_id)
		button.tooltip_text = String(entry.get("display_name", character_id))
		_apply_room_square_button_style(button, _color_for_character_id(character_id))
		_add_formal_character_preview(button, character_id, "", 72.0)
		button.pressed.connect(Callable(self, "_select_formal_character").bind(character_id))
		_formal_character_grid.add_child(button)
	if _formal_character_page_label != null:
		_formal_character_page_label.text = "%d / %d" % [_formal_character_page + 1, max_page + 1]
	if _formal_character_prev_button != null:
		_formal_character_prev_button.disabled = _formal_character_page <= 0
	if _formal_character_next_button != null:
		_formal_character_next_button.disabled = _formal_character_page >= max_page


func _create_formal_character_placeholder() -> Control:
	var placeholder := PanelContainer.new()
	placeholder.custom_minimum_size = Vector2(72, 72)
	placeholder.add_theme_stylebox_override("panel", _make_room_style(Color(0.72, 0.78, 0.80, 0.58), Color(0.48, 0.62, 0.68, 0.8), 6))
	return placeholder


func _add_formal_character_preview(parent: Control, character_id: String, character_skin_id: String, size: float) -> void:
	if parent == null or character_id.strip_edges().is_empty():
		return
	var preview = RoomCharacterPreviewScene.instantiate()
	if preview == null:
		return
	if preview is Control:
		var preview_control := preview as Control
		preview_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
		preview_control.custom_minimum_size = Vector2(size, size)
		preview_control.set_anchors_preset(Control.PRESET_FULL_RECT)
		preview_control.offset_left = 3.0
		preview_control.offset_top = 3.0
		preview_control.offset_right = -3.0
		preview_control.offset_bottom = -3.0
		preview_control.set("stretch", true)
	parent.add_child(preview)
	if preview.has_method("configure_preview"):
		preview.call_deferred("configure_preview", character_id, character_skin_id)


func _color_for_character_id(character_id: String) -> Color:
	var hash_value: int = abs(character_id.hash())
	var hue := float(hash_value % 360) / 360.0
	return Color.from_hsv(hue, 0.48, 0.86, 1.0)


func _get_formal_character_max_page(entry_count: int) -> int:
	if entry_count <= 0:
		return 0
	return int(ceil(float(entry_count) / 8.0)) - 1


func _change_formal_character_page(delta: int) -> void:
	var entries := CharacterCatalogScript.get_character_entries()
	_formal_character_page = clampi(_formal_character_page + delta, 0, _get_formal_character_max_page(entries.size()))
	_build_formal_character_buttons()
	_refresh_formal_loadout_selection(_last_room_view_model)


func _build_formal_team_buttons() -> void:
	if _formal_team_row == null:
		return
	for child in _formal_team_row.get_children():
		child.queue_free()
	for team_id in RoomTeamPaletteScript.TEAM_IDS:
		var button := Button.new()
		button.text = RoomTeamPaletteScript.label_for_team(team_id)
		button.custom_minimum_size = Vector2(24, 24)
		button.toggle_mode = true
		button.set_meta("team_id", team_id)
		_apply_room_team_button_style(button, RoomTeamPaletteScript.color_for_team(team_id))
		button.pressed.connect(Callable(self, "_select_formal_team").bind(team_id))
		_formal_team_row.add_child(button)


func _select_formal_character(character_id: String) -> void:
	_select_metadata(character_selector, character_id)
	_on_profile_selector_changed()


func _select_formal_team(team_id: int) -> void:
	_select_team_id(team_id)
	_on_profile_selector_changed()


func _refresh_reference_room_panels(snapshot: RoomSnapshot, view_model: Dictionary) -> void:
	_last_room_snapshot = snapshot
	_last_room_view_model = view_model.duplicate(true)
	_refresh_formal_room_properties(snapshot, view_model)
	_refresh_formal_room_slots(snapshot, view_model)
	_refresh_formal_room_actions(snapshot, view_model)
	_refresh_formal_loadout_selection(view_model)


func _refresh_formal_room_properties(snapshot: RoomSnapshot, view_model: Dictionary) -> void:
	if snapshot == null:
		return
	var is_custom_room := bool(view_model.get("is_custom_room", false))
	var is_match_room := bool(view_model.get("is_match_room", false))
	if _formal_choose_mode_button != null:
		_formal_choose_mode_button.visible = is_custom_room
	if _formal_room_property_button != null:
		_formal_room_property_button.visible = is_custom_room
	if _formal_room_name_label != null:
		_formal_room_name_label.text = "房间: %s" % String(view_model.get("room_display_name", view_model.get("title_text", "")))
	if _formal_room_mode_label != null:
		var mode_text := String(view_model.get("selected_mode_display_name", snapshot.mode_id))
		if is_custom_room:
			mode_text = _formal_display_mode
		if is_match_room:
			mode_text = "%s  %s" % [String(snapshot.queue_type), String(snapshot.match_format_id)]
		_formal_room_mode_label.text = "模式: %s" % mode_text
	if _formal_room_map_label != null:
		_formal_room_map_label.text = "地图: %s" % String(view_model.get("selected_map_id", snapshot.selected_map_id))
	if _formal_room_member_label != null:
		_formal_room_member_label.text = "人数: %d / %d" % [snapshot.members.size(), _resolve_formal_open_slot_count(snapshot, view_model)]
	if _formal_map_preview_label != null:
		var map_name := String(view_model.get("selected_map_id", snapshot.selected_map_id))
		_formal_map_preview_label.text = map_name if not map_name.is_empty() else "随机地图"


func _refresh_formal_room_slots(snapshot: RoomSnapshot, view_model: Dictionary) -> void:
	if _formal_slot_grid == null or snapshot == null:
		return
	for child in _formal_slot_grid.get_children():
		child.queue_free()
	var open_slot_count := _resolve_formal_open_slot_count(snapshot, view_model)
	var max_player_count := int(view_model.get("max_player_count", snapshot.max_players))
	if max_player_count <= 0:
		max_player_count = FORMAL_ROOM_SLOT_COUNT
	for slot_index in range(FORMAL_ROOM_SLOT_COUNT):
		var member := _find_member_for_slot(snapshot, slot_index)
		var is_open := slot_index < open_slot_count
		if bool(view_model.get("is_custom_room", false)):
			is_open = _is_formal_custom_slot_open(slot_index, max_player_count)
		_formal_slot_grid.add_child(_create_formal_slot_card(slot_index, member, is_open, view_model))


func _create_formal_slot_card(slot_index: int, member: RoomMemberState, is_open: bool, view_model: Dictionary) -> Control:
	var button := Button.new()
	button.custom_minimum_size = Vector2(128, 128)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	if member != null:
		button.text = ""
		button.tooltip_text = member.player_name
		button.set_meta("ui_asset_id", "ui.room.slot.occupied")
		button.pressed.connect(Callable(self, "_show_formal_member_profile").bind(_member_to_profile_payload(member)))
		_apply_room_square_button_style(button, RoomTeamPaletteScript.color_for_team(member.team_id))
		_add_formal_character_preview(button, member.character_id, member.character_skin_id, 122.0)
	elif is_open:
		button.text = ""
		button.tooltip_text = "空位"
		button.disabled = not _can_toggle_formal_custom_slot(view_model)
		button.set_meta("ui_asset_id", "ui.room.slot.empty")
		button.pressed.connect(Callable(self, "_toggle_formal_slot").bind(slot_index))
		_apply_room_square_button_style(button, Color(0.40, 0.53, 0.54, 0.86))
	else:
		button.text = ""
		button.tooltip_text = "已关闭"
		button.disabled = not _can_toggle_formal_custom_slot(view_model)
		button.set_meta("ui_asset_id", "ui.room.slot.closed")
		button.pressed.connect(Callable(self, "_toggle_formal_slot").bind(slot_index))
		_apply_room_square_button_style(button, Color(0.22, 0.25, 0.26, 0.92))
	return button


func _refresh_formal_room_actions(snapshot: RoomSnapshot, view_model: Dictionary) -> void:
	if snapshot == null:
		return
	var is_host := _is_local_host(snapshot)
	var is_match_room := bool(view_model.get("is_match_room", false))
	if ready_button != null:
		ready_button.text = "取消准备" if bool(view_model.get("local_member_ready", false)) else "准备"
		ready_button.visible = not is_host
		ready_button.disabled = not bool(view_model.get("can_ready", false))
	if start_button != null:
		start_button.text = "开始"
		start_button.visible = is_host and not is_match_room
		start_button.disabled = not bool(view_model.get("can_start", false))
	if enter_queue_button != null:
		enter_queue_button.text = "开始"
		enter_queue_button.visible = is_host and is_match_room
		enter_queue_button.disabled = not bool(view_model.get("can_enter_queue", false))
	if cancel_queue_button != null:
		cancel_queue_button.visible = is_match_room and bool(view_model.get("can_cancel_queue", false))
	if leave_room_button != null:
		leave_room_button.text = "离开房间"
	if _formal_feedback_label != null:
		_formal_feedback_label.text = String(view_model.get("blocker_text", ""))


func _refresh_formal_loadout_selection(view_model: Dictionary) -> void:
	var selected_character_id := _selected_metadata(character_selector)
	var selected_team_id := _selected_team_id()
	if selected_character_id.is_empty():
		selected_character_id = String(view_model.get("local_character_id", ""))
	if _formal_character_grid != null:
		for child in _formal_character_grid.get_children():
			if child is Button:
				(child as Button).button_pressed = String(child.get_meta("character_id", "")) == selected_character_id
	if _formal_team_row != null:
		for child in _formal_team_row.get_children():
			if child is Button:
				(child as Button).button_pressed = int(child.get_meta("team_id", 0)) == selected_team_id


func _find_member_for_slot(snapshot: RoomSnapshot, slot_index: int) -> RoomMemberState:
	if snapshot == null:
		return null
	for member in snapshot.sorted_members():
		if member != null and int(member.slot_index) == slot_index:
			return member
	return null


func _resolve_formal_open_slot_count(snapshot: RoomSnapshot, view_model: Dictionary) -> int:
	if bool(view_model.get("is_match_room", false)):
		return clampi(int(snapshot.required_party_size), 1, FORMAL_ROOM_SLOT_COUNT)
	if bool(view_model.get("is_custom_room", false)):
		_sync_formal_closed_slots_from_snapshot(snapshot, view_model)
		return clampi(_formal_custom_open_slots, FORMAL_ROOM_MIN_CUSTOM_OPEN_SLOTS, FORMAL_ROOM_SLOT_COUNT)
	return clampi(maxi(snapshot.members.size(), 1), 1, FORMAL_ROOM_SLOT_COUNT)


func _is_local_host(snapshot: RoomSnapshot) -> bool:
	if snapshot == null:
		return false
	for member in snapshot.members:
		if member != null and member.is_local_player and member.is_owner:
			return true
	return _app_runtime != null and int(_app_runtime.local_peer_id) == int(snapshot.owner_peer_id)


func _can_toggle_formal_custom_slot(view_model: Dictionary) -> bool:
	return bool(view_model.get("is_custom_room", false)) and bool(view_model.get("can_edit_selection", false)) and _last_room_snapshot != null and _is_local_host(_last_room_snapshot)


func _toggle_formal_slot(slot_index: int) -> void:
	if _last_room_snapshot == null or not _can_toggle_formal_custom_slot(_last_room_view_model):
		return
	if _find_member_for_slot(_last_room_snapshot, slot_index) != null:
		_set_room_feedback("已有玩家的格子不能关闭")
		return
	var open_slots := _last_room_snapshot.open_slot_indices.duplicate()
	if open_slots.is_empty():
		var max_player_count := int(_last_room_view_model.get("max_player_count", _last_room_snapshot.max_players))
		if max_player_count <= 0:
			max_player_count = FORMAL_ROOM_SLOT_COUNT
		for index in range(max_player_count):
			open_slots.append(index)
	if open_slots.has(slot_index):
		var required_open_count := _required_formal_open_slot_count(_last_room_snapshot, _last_room_view_model)
		if open_slots.size() <= required_open_count:
			_set_room_feedback("至少保留 2 个格子")
			return
		open_slots.erase(slot_index)
	else:
		open_slots.append(slot_index)
	open_slots.sort()
	if _room_use_case == null or _room_use_case.room_client_gateway == null:
		_set_room_feedback("房间服务未连接")
		return
	_room_use_case.room_client_gateway.request_update_selection(
		String(_last_room_snapshot.selected_map_id),
		String(_last_room_snapshot.rule_set_id),
		String(_last_room_snapshot.mode_id),
		open_slots
	)
	_set_room_feedback("槽位设置已提交")


func _required_formal_open_slot_count(snapshot: RoomSnapshot, view_model: Dictionary) -> int:
	var max_player_count := int(view_model.get("max_player_count", snapshot.max_players))
	if max_player_count <= 0:
		max_player_count = FORMAL_ROOM_SLOT_COUNT
	var required := snapshot.members.size()
	return max(required, FORMAL_ROOM_MIN_CUSTOM_OPEN_SLOTS)


func _is_formal_custom_slot_open(slot_index: int, max_player_count: int) -> bool:
	return slot_index < max_player_count and not _formal_closed_slots.has(slot_index)


func _sync_formal_closed_slots_from_snapshot(snapshot: RoomSnapshot, view_model: Dictionary) -> void:
	_formal_closed_slots.clear()
	if snapshot == null:
		return
	var max_player_count := int(view_model.get("max_player_count", snapshot.max_players))
	if max_player_count <= 0:
		max_player_count = FORMAL_ROOM_SLOT_COUNT
	for slot_index in range(FORMAL_ROOM_SLOT_COUNT):
		var slot_open := snapshot.open_slot_indices.has(slot_index)
		if snapshot.open_slot_indices.is_empty() and slot_index < max_player_count:
			slot_open = true
		if slot_index >= max_player_count or not slot_open:
			_formal_closed_slots[slot_index] = true
	_formal_custom_open_slots = max_player_count if snapshot.open_slot_indices.is_empty() else snapshot.open_slot_indices.size()


func _apply_formal_slot_capacity(max_player_count: int) -> void:
	max_player_count = clampi(max_player_count, FORMAL_ROOM_MIN_CUSTOM_OPEN_SLOTS, FORMAL_ROOM_SLOT_COUNT)
	for slot_index in range(FORMAL_ROOM_SLOT_COUNT):
		if slot_index >= max_player_count:
			_formal_closed_slots[slot_index] = true
	while _count_formal_open_custom_slots() < FORMAL_ROOM_MIN_CUSTOM_OPEN_SLOTS:
		if not _open_next_formal_closed_slot(max_player_count):
			break


func _count_formal_open_custom_slots() -> int:
	var count := 0
	for slot_index in range(FORMAL_ROOM_SLOT_COUNT):
		if not _formal_closed_slots.has(slot_index):
			count += 1
	return count


func _open_next_formal_closed_slot(max_player_count: int) -> bool:
	for slot_index in range(clampi(max_player_count, 1, FORMAL_ROOM_SLOT_COUNT)):
		if _formal_closed_slots.has(slot_index):
			_formal_closed_slots.erase(slot_index)
			return true
	return false


func _ensure_formal_room_popups() -> void:
	if _formal_mode_popup == null:
		_formal_mode_popup = PopupPanel.new()
		_formal_mode_popup.name = "FormalModePopup"
		room_root.add_child(_formal_mode_popup)
		_formal_mode_popup_content = VBoxContainer.new()
		_formal_mode_popup_content.add_theme_constant_override("separation", 8)
		_formal_mode_popup.add_child(_formal_mode_popup_content)
	if _formal_property_popup == null:
		_formal_property_popup = PopupPanel.new()
		_formal_property_popup.name = "FormalRoomPropertyPopup"
		room_root.add_child(_formal_property_popup)
		var property_vbox := VBoxContainer.new()
		property_vbox.add_theme_constant_override("separation", 8)
		_formal_property_popup.add_child(property_vbox)
		var title := Label.new()
		title.text = "房间属性"
		property_vbox.add_child(title)
		_formal_property_name_input = LineEdit.new()
		_formal_property_name_input.placeholder_text = "房间名字"
		property_vbox.add_child(_formal_property_name_input)
		var confirm := _create_formal_room_button("确定", _on_formal_room_property_confirmed)
		property_vbox.add_child(confirm)
	if _formal_map_popup == null:
		_formal_map_popup = PopupPanel.new()
		_formal_map_popup.name = "FormalMapPopup"
		room_root.add_child(_formal_map_popup)
		_formal_map_popup_content = VBoxContainer.new()
		_formal_map_popup_content.add_theme_constant_override("separation", 8)
		_formal_map_popup.add_child(_formal_map_popup_content)
	if _formal_profile_popup == null:
		_formal_profile_popup = PopupPanel.new()
		_formal_profile_popup.name = "FormalMemberProfilePopup"
		room_root.add_child(_formal_profile_popup)
		_formal_profile_popup_content = VBoxContainer.new()
		_formal_profile_popup_content.add_theme_constant_override("separation", 8)
		_formal_profile_popup.add_child(_formal_profile_popup_content)


func _member_to_profile_payload(member: RoomMemberState) -> Dictionary:
	if member == null:
		return {}
	return {
		"name": member.player_name,
		"character": member.character_id,
		"team": String.chr(64 + max(1, int(member.team_id))),
		"ready": "已准备" if member.ready else "未准备",
		"owner": "房主" if member.is_owner else "成员",
	}


func _show_formal_member_profile(profile: Dictionary) -> void:
	_ensure_formal_room_popups()
	if _formal_profile_popup == null or _formal_profile_popup_content == null:
		return
	for child in _formal_profile_popup_content.get_children():
		child.queue_free()
	var avatar := ColorRect.new()
	avatar.custom_minimum_size = Vector2(96, 96)
	avatar.color = Color(0.55, 0.72, 0.78, 1.0)
	_formal_profile_popup_content.add_child(avatar)
	for line in [
		"名字: %s" % String(profile.get("name", "Player")),
		"角色: %s" % String(profile.get("character", "-")),
		"队伍: %s" % String(profile.get("team", "-")),
		"状态: %s" % String(profile.get("ready", "-")),
		String(profile.get("owner", "")),
	]:
		var label := Label.new()
		label.text = line
		_formal_profile_popup_content.add_child(label)
	_formal_profile_popup.popup_centered(Vector2i(260, 250))


func _on_formal_choose_mode_pressed() -> void:
	_ensure_formal_room_popups()
	if _formal_mode_popup_content == null:
		return
	for child in _formal_mode_popup_content.get_children():
		child.queue_free()
	var title := Label.new()
	title.text = "选择模式"
	_formal_mode_popup_content.add_child(title)
	var contest := _create_formal_room_button("竞技模式", Callable(self, "_select_formal_display_mode").bind("竞技模式"))
	_formal_mode_popup_content.add_child(contest)
	var adventure := _create_formal_room_button("探险模式", Callable(self, "_select_formal_display_mode").bind("探险模式"))
	adventure.disabled = true
	_formal_mode_popup_content.add_child(adventure)
	_formal_mode_popup.popup_centered(Vector2i(260, 240))


func _select_formal_display_mode(mode_name: String) -> void:
	_formal_display_mode = mode_name
	if _formal_room_mode_label != null:
		_formal_room_mode_label.text = "模式: %s" % _formal_display_mode
	if _formal_mode_popup != null:
		_formal_mode_popup.hide()


func _on_formal_room_property_pressed() -> void:
	_ensure_formal_room_popups()
	if _formal_property_name_input != null:
		_formal_property_name_input.text = String(_last_room_view_model.get("room_display_name", ""))
	if _formal_property_popup != null:
		_formal_property_popup.popup_centered(Vector2i(320, 150))


func _on_formal_room_property_confirmed() -> void:
	var room_name := _formal_property_name_input.text.strip_edges() if _formal_property_name_input != null else ""
	if room_name.is_empty():
		_set_room_feedback("房间名字不能为空")
		return
	if _formal_room_name_label != null:
		_formal_room_name_label.text = "房间: %s" % room_name
	_set_room_feedback("房间名修改待接入服务端同步接口")
	if _formal_property_popup != null:
		_formal_property_popup.hide()


func _on_formal_choose_map_pressed() -> void:
	_ensure_formal_room_popups()
	if _formal_map_popup_content == null:
		return
	for child in _formal_map_popup_content.get_children():
		child.queue_free()
	if bool(_last_room_view_model.get("is_match_room", false)):
		_build_match_mode_popup()
	else:
		_build_custom_map_popup()
	_formal_map_popup.popup_centered(Vector2i(360, 520))


func _build_custom_map_popup() -> void:
	var title := Label.new()
	title.text = "选择地图"
	_formal_map_popup_content.add_child(title)
	for mode_entry in MapSelectionCatalogScript.get_custom_room_mode_entries():
		var mode_id := String(mode_entry.get("mode_id", ""))
		var mode_label := Label.new()
		mode_label.text = String(mode_entry.get("display_name", mode_id))
		mode_label.add_theme_font_size_override("font_size", 18)
		_formal_map_popup_content.add_child(mode_label)
		for map_entry in MapSelectionCatalogScript.get_custom_room_maps_by_mode(mode_id):
			var map_id := String(map_entry.get("map_id", ""))
			var max_players := int(map_entry.get("max_player_count", FORMAL_ROOM_SLOT_COUNT))
			var label_text := "%s    %d人" % [String(map_entry.get("display_name", map_id)), max_players]
			var button := _create_formal_room_button(label_text, Callable(self, "_select_formal_custom_map").bind(map_id, max_players))
			_formal_map_popup_content.add_child(button)


func _build_match_mode_popup() -> void:
	var title := Label.new()
	title.text = "选择匹配模式"
	_formal_map_popup_content.add_child(title)
	var queue_type := String(_last_room_snapshot.queue_type) if _last_room_snapshot != null else "casual"
	var match_format_id := String(_last_room_snapshot.match_format_id) if _last_room_snapshot != null else "1v1"
	for mode_entry in MapSelectionCatalogScript.get_match_room_mode_entries(queue_type, match_format_id):
		var mode_id := String(mode_entry.get("mode_id", ""))
		var button := _create_formal_room_button(String(mode_entry.get("display_name", mode_id)), Callable(self, "_select_formal_match_mode").bind(mode_id))
		_formal_map_popup_content.add_child(button)


func _select_formal_custom_map(map_id: String, max_players: int) -> void:
	if _last_room_snapshot != null and _last_room_snapshot.members.size() > max_players:
		_set_room_feedback("当前人数超过地图人数要求")
		return
	_formal_closed_slots.clear()
	_apply_formal_slot_capacity(max_players)
	_formal_custom_open_slots = _count_formal_open_custom_slots()
	_select_metadata(map_selector, map_id)
	_on_selection_changed()
	if _formal_map_popup != null:
		_formal_map_popup.hide()


func _select_formal_match_mode(mode_id: String) -> void:
	if match_mode_multi_select != null:
		match_mode_multi_select.deselect_all()
		for index in range(match_mode_multi_select.item_count):
			if String(match_mode_multi_select.get_item_metadata(index)) == mode_id:
				match_mode_multi_select.select(index, false)
				break
	_on_match_mode_multi_select_changed()
	if _formal_map_popup != null:
		_formal_map_popup.hide()


func _ensure_room_background() -> void:
	if room_root == null:
		return
	var background: ColorRect = room_root.get_node_or_null("FormalBackground")
	if background == null:
		background = ColorRect.new()
		background.name = "FormalBackground"
		room_root.add_child(background)
		room_root.move_child(background, 0)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.055, 0.095, 0.13, 1.0)
	background.set_meta("ui_asset_id", "ui.room.bg.main")


func _apply_room_card_style(card: PanelContainer) -> void:
	if card == null:
		return
	card.add_theme_stylebox_override("panel", _make_room_style(Color(0.12, 0.17, 0.22, 0.95), Color(0.30, 0.47, 0.62, 0.72), 8))
	card.set_meta("ui_asset_id", "ui.room.panel.config")


func _apply_room_button_style(button: Button) -> void:
	if button == null:
		return
	button.custom_minimum_size = Vector2(max(button.custom_minimum_size.x, 128.0), 40.0)
	button.add_theme_stylebox_override("normal", _make_room_style(Color(0.24, 0.32, 0.40, 1.0), Color(0.48, 0.64, 0.78, 0.85), 6))
	button.add_theme_stylebox_override("hover", _make_room_style(Color(0.32, 0.42, 0.52, 1.0), Color(0.64, 0.82, 0.98, 1.0), 6))
	button.add_theme_stylebox_override("pressed", _make_room_style(Color(0.16, 0.22, 0.28, 1.0), Color(0.56, 0.72, 0.88, 1.0), 6))


func _apply_room_small_button_style(button: Button) -> void:
	if button == null:
		return
	button.add_theme_stylebox_override("normal", _make_room_style(Color(0.24, 0.32, 0.40, 1.0), Color(0.48, 0.64, 0.78, 0.85), 4))
	button.add_theme_stylebox_override("hover", _make_room_style(Color(0.32, 0.42, 0.52, 1.0), Color(0.64, 0.82, 0.98, 1.0), 4))
	button.add_theme_stylebox_override("pressed", _make_room_style(Color(0.16, 0.22, 0.28, 1.0), Color(0.56, 0.72, 0.88, 1.0), 4))


func _apply_room_team_button_style(button: Button, fill_color: Color) -> void:
	if button == null:
		return
	button.add_theme_stylebox_override("normal", _make_room_style(fill_color, Color(0.26, 0.34, 0.42, 0.95), 4))
	button.add_theme_stylebox_override("hover", _make_room_style(fill_color.lightened(0.12), Color(0.86, 0.94, 1.0, 1.0), 4))
	button.add_theme_stylebox_override("pressed", _make_room_style(fill_color.darkened(0.14), Color(1.0, 0.96, 0.62, 1.0), 4))


func _apply_room_square_button_style(button: Button, fill_color: Color) -> void:
	if button == null:
		return
	var normal := _make_room_style(fill_color, Color(0.32, 0.52, 0.60, 0.9), 8)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", _make_room_style(fill_color.lightened(0.10), Color(0.70, 0.88, 0.96, 1.0), 8))
	button.add_theme_stylebox_override("pressed", _make_room_style(fill_color.darkened(0.14), Color(0.82, 0.92, 1.0, 1.0), 8))
	button.add_theme_stylebox_override("disabled", normal)


func _apply_room_input_style(input: LineEdit) -> void:
	if input == null:
		return
	input.custom_minimum_size = Vector2(max(input.custom_minimum_size.x, 220.0), 38.0)
	input.add_theme_stylebox_override("normal", _make_room_style(Color(0.07, 0.10, 0.13, 1.0), Color(0.26, 0.38, 0.50, 0.8), 6))
	input.add_theme_stylebox_override("focus", _make_room_style(Color(0.08, 0.12, 0.16, 1.0), Color(0.96, 0.76, 0.28, 1.0), 6))


func _apply_room_asset_ids() -> void:
	_set_room_asset_meta(room_root, "ui.room.bg.main")
	_set_room_asset_meta(summary_card, "ui.room.panel.config")
	_set_room_asset_meta(local_loadout_card, "ui.room.panel.loadout_preview")
	_set_room_asset_meta(room_selection_card, "ui.room.panel.map_select")
	_set_room_asset_meta(member_card, "ui.room.slot.occupied")
	_set_room_asset_meta(preview_card, "ui.room.preview.character_frame")
	_set_room_asset_meta(start_button, "ui.room.button.start.normal")
	_set_room_asset_meta(ready_button, "ui.room.button.ready.normal")
	_set_room_asset_meta(back_to_lobby_button, "ui.room.button.back.normal")


func _make_room_style(color: Color, border_color: Color, radius: int) -> StyleBoxFlat:
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
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 12.0
	style.content_margin_bottom = 12.0
	return style


func _set_room_asset_meta(node: Node, asset_id: String) -> void:
	if node == null:
		return
	node.set_meta("ui_asset_id", asset_id)
