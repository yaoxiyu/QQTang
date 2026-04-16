extends Node

const AppRuntimeRootScript = preload("res://app/flow/app_runtime_root.gd")
const BubbleCatalogScript = preload("res://content/bubbles/catalog/bubble_catalog.gd")
const BubbleSkinCatalogScript = preload("res://content/bubble_skins/catalog/bubble_skin_catalog.gd")
const CharacterCatalogScript = preload("res://content/characters/catalog/character_catalog.gd")
const CharacterSkinCatalogScript = preload("res://content/character_skins/catalog/character_skin_catalog.gd")
const MapSelectionCatalogScript = preload("res://content/maps/catalog/map_selection_catalog.gd")
const RuleSetCatalogScript = preload("res://content/rulesets/catalog/rule_set_catalog.gd")
const RoomScenePresenterScript = preload("res://app/front/room/room_scene_presenter.gd")
const RoomViewModelBuilderScript = preload("res://app/front/room/room_view_model_builder.gd")
const LogFrontScript = preload("res://app/logging/log_front.gd")
const ROOM_SCENE_LOG_TAG := "front.room.scene"

@onready var room_hud_controller: Node = get_node_or_null("RoomHudController")
@onready var room_root: Control = get_node_or_null("RoomRoot")
@onready var main_layout: VBoxContainer = get_node_or_null("RoomRoot/MainLayout")
@onready var title_label: Label = get_node_or_null("RoomRoot/MainLayout/TopBar/TitleLabel")
@onready var back_to_lobby_button: Button = get_node_or_null("RoomRoot/MainLayout/TopBar/BackToLobbyButton")
@onready var room_meta_label: Label = get_node_or_null("RoomRoot/MainLayout/TopBar/RoomMetaLabel")
@onready var room_kind_label: Label = get_node_or_null("RoomRoot/MainLayout/SummaryCard/SummaryVBox/RoomKindLabel")
@onready var room_display_name_label: Label = get_node_or_null("RoomRoot/MainLayout/SummaryCard/SummaryVBox/RoomDisplayNameLabel")
@onready var room_id_value_label: LineEdit = get_node_or_null("RoomRoot/MainLayout/SummaryCard/SummaryVBox/RoomIdRow/RoomIdValueLabel")
@onready var connection_status_label: Label = get_node_or_null("RoomRoot/MainLayout/SummaryCard/SummaryVBox/ConnectionStatusLabel")
@onready var auth_binding_label: Label = get_node_or_null("RoomRoot/MainLayout/SummaryCard/SummaryVBox/AuthBindingLabel")
@onready var owner_label: Label = get_node_or_null("RoomRoot/MainLayout/SummaryCard/SummaryVBox/OwnerLabel")
@onready var blocker_label: Label = get_node_or_null("RoomRoot/MainLayout/SummaryCard/SummaryVBox/BlockerLabel")
@onready var lifecycle_status_label: Label = get_node_or_null("RoomRoot/MainLayout/SummaryCard/SummaryVBox/LifecycleStatusLabel")
@onready var pending_action_status_label: Label = get_node_or_null("RoomRoot/MainLayout/SummaryCard/SummaryVBox/PendingActionStatusLabel")
@onready var reconnect_window_label: Label = get_node_or_null("RoomRoot/MainLayout/SummaryCard/SummaryVBox/ReconnectWindowLabel")
@onready var active_match_resume_label: Label = get_node_or_null("RoomRoot/MainLayout/SummaryCard/SummaryVBox/ActiveMatchResumeLabel")
@onready var player_name_input: LineEdit = get_node_or_null("RoomRoot/MainLayout/LocalLoadoutCard/LocalLoadoutVBox/PlayerNameRow/PlayerNameInput")
@onready var team_selector: OptionButton = get_node_or_null("RoomRoot/MainLayout/LocalLoadoutCard/LocalLoadoutVBox/TeamRow/TeamSelector")
@onready var character_selector: OptionButton = get_node_or_null("RoomRoot/MainLayout/LocalLoadoutCard/LocalLoadoutVBox/CharacterRow/CharacterSelector")
@onready var character_skin_selector: OptionButton = get_node_or_null("RoomRoot/MainLayout/LocalLoadoutCard/LocalLoadoutVBox/CharacterSkinRow/CharacterSkinSelector")
@onready var bubble_selector: OptionButton = get_node_or_null("RoomRoot/MainLayout/LocalLoadoutCard/LocalLoadoutVBox/BubbleRow/BubbleSelector")
@onready var bubble_skin_selector: OptionButton = get_node_or_null("RoomRoot/MainLayout/LocalLoadoutCard/LocalLoadoutVBox/BubbleSkinRow/BubbleSkinSelector")
@onready var map_selector: OptionButton = get_node_or_null("RoomRoot/MainLayout/RoomSelectionCard/RoomSelectionVBox/MapRow/MapSelector")
@onready var rule_value_label: Label = get_node_or_null("RoomRoot/MainLayout/RoomSelectionCard/RoomSelectionVBox/RuleRow/RuleValueLabel")
@onready var game_mode_selector: OptionButton = get_node_or_null("RoomRoot/MainLayout/RoomSelectionCard/RoomSelectionVBox/ModeRow/GameModeSelector")
@onready var match_format_selector: OptionButton = get_node_or_null("RoomRoot/MainLayout/RoomSelectionCard/RoomSelectionVBox/MatchFormatRow/MatchFormatSelector")
@onready var match_mode_multi_select: ItemList = get_node_or_null("RoomRoot/MainLayout/RoomSelectionCard/RoomSelectionVBox/MatchModeRow/MatchModeMultiSelect")
@onready var eligible_map_pool_hint_label: Label = get_node_or_null("RoomRoot/MainLayout/RoomSelectionCard/RoomSelectionVBox/MatchModeRow/EligibleMapPoolHintLabel")
@onready var invite_code_value_label: LineEdit = get_node_or_null("RoomRoot/MainLayout/RoomSelectionCard/RoomSelectionVBox/InviteRow/InviteCodeValueLabel")
@onready var copy_invite_code_button: Button = get_node_or_null("RoomRoot/MainLayout/RoomSelectionCard/RoomSelectionVBox/InviteRow/CopyInviteCodeButton")
@onready var queue_status_label: Label = get_node_or_null("RoomRoot/MainLayout/RoomSelectionCard/RoomSelectionVBox/QueueStatusRow/QueueStatusLabel")
@onready var queue_error_label: Label = get_node_or_null("RoomRoot/MainLayout/RoomSelectionCard/RoomSelectionVBox/QueueStatusRow/QueueErrorLabel")
@onready var member_list: VBoxContainer = get_node_or_null("RoomRoot/MainLayout/MemberCard/MemberVBox/MemberList")
@onready var map_preview_label: Label = get_node_or_null("RoomRoot/MainLayout/PreviewCard/PreviewVBox/MapPreviewLabel")
@onready var rule_preview_label: Label = get_node_or_null("RoomRoot/MainLayout/PreviewCard/PreviewVBox/RulePreviewLabel")
@onready var mode_preview_label: Label = get_node_or_null("RoomRoot/MainLayout/PreviewCard/PreviewVBox/ModePreviewLabel")
@onready var team_preview_label: Label = get_node_or_null("RoomRoot/MainLayout/PreviewCard/PreviewVBox/TeamPreviewLabel")
@onready var character_preview_label: Label = get_node_or_null("RoomRoot/MainLayout/PreviewCard/PreviewVBox/CharacterPreviewLabel")
@onready var character_preview_viewport = get_node_or_null("RoomRoot/MainLayout/PreviewCard/PreviewVBox/CharacterPreviewViewport")
@onready var character_skin_preview_label: Label = get_node_or_null("RoomRoot/MainLayout/PreviewCard/PreviewVBox/CharacterSkinPreviewLabel")
@onready var character_skin_icon: TextureRect = get_node_or_null("RoomRoot/MainLayout/PreviewCard/PreviewVBox/CharacterSkinIcon")
@onready var bubble_preview_label: Label = get_node_or_null("RoomRoot/MainLayout/PreviewCard/PreviewVBox/BubblePreviewLabel")
@onready var bubble_skin_preview_label: Label = get_node_or_null("RoomRoot/MainLayout/PreviewCard/PreviewVBox/BubbleSkinPreviewLabel")
@onready var bubble_skin_icon: TextureRect = get_node_or_null("RoomRoot/MainLayout/PreviewCard/PreviewVBox/BubbleSkinIcon")
@onready var leave_room_button: Button = get_node_or_null("RoomRoot/MainLayout/ActionRow/LeaveRoomButton")
@onready var ready_button: Button = get_node_or_null("RoomRoot/MainLayout/ActionRow/ReadyButton")
@onready var start_button: Button = get_node_or_null("RoomRoot/MainLayout/ActionRow/StartButton")
@onready var enter_queue_button: Button = get_node_or_null("RoomRoot/MainLayout/ActionRow/EnterQueueButton")
@onready var cancel_queue_button: Button = get_node_or_null("RoomRoot/MainLayout/ActionRow/CancelQueueButton")
@onready var add_opponent_button: Button = get_node_or_null("RoomRoot/MainLayout/ActionRow/AddOpponentButton")
@onready var room_debug_panel: PanelContainer = get_node_or_null("RoomRoot/MainLayout/RoomDebugPanel")
@onready var debug_label: Label = get_node_or_null("RoomRoot/MainLayout/RoomDebugPanel/DebugLabel")
@onready var battle_allocation_label: Label = get_node_or_null("RoomRoot/MainLayout/SummaryCard/SummaryVBox/BattleAllocationLabel")

var _app_runtime: Node = null
var _room_controller: Node = null
var _front_flow: Node = null
var _room_use_case: RoomUseCase = null
var _room_scene_presenter: RoomScenePresenter = RoomScenePresenterScript.new()
var _room_view_model_builder: RoomViewModelBuilder = RoomViewModelBuilderScript.new()
var _suppress_selection_callbacks: bool = false


func _ready() -> void:
	_ensure_scroll_layout()
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


func _ensure_scroll_layout() -> void:
	_ensure_action_buttons()
	if room_root == null or main_layout == null:
		return
	if room_root.has_node("RoomScroll"):
		return
	var scroll := ScrollContainer.new()
	scroll.name = "RoomScroll"
	scroll.layout_mode = 3
	scroll.anchors_preset = Control.PRESET_FULL_RECT
	scroll.anchor_right = 1.0
	scroll.anchor_bottom = 1.0
	scroll.grow_horizontal = Control.GROW_DIRECTION_BOTH
	scroll.grow_vertical = Control.GROW_DIRECTION_BOTH
	scroll.follow_focus = true
	room_root.remove_child(main_layout)
	room_root.add_child(scroll)
	room_root.move_child(scroll, 0)
	scroll.add_child(main_layout)


func _ensure_action_buttons() -> void:
	var action_row: HBoxContainer = get_node_or_null("RoomRoot/MainLayout/ActionRow")
	if action_row == null:
		return
	if add_opponent_button == null:
		add_opponent_button = Button.new()
		add_opponent_button.name = "AddOpponentButton"
		add_opponent_button.custom_minimum_size = Vector2(170, 44)
		add_opponent_button.visible = false
		action_row.add_child(add_opponent_button)


func _exit_tree() -> void:
	if _room_controller != null:
		if _room_controller.room_snapshot_changed.is_connected(_on_room_snapshot_changed):
			_room_controller.room_snapshot_changed.disconnect(_on_room_snapshot_changed)
		if _room_controller.start_match_requested.is_connected(_on_start_match_requested):
			_room_controller.start_match_requested.disconnect(_on_start_match_requested)


func _populate_selectors() -> void:
	_suppress_selection_callbacks = true
	_populate_character_selector()
	_populate_team_selector()
	_populate_character_skin_selector()
	_populate_bubble_selector()
	_populate_bubble_skin_selector()
	_populate_mode_selector()
	_populate_map_selector()
	_populate_match_format_selector("casual")
	_populate_match_mode_multi_select("casual", "1v1")
	_suppress_selection_callbacks = false


func _populate_character_selector() -> void:
	if character_selector == null:
		return
	character_selector.clear()
	var owned_ids := _get_owned_ids("character")
	var added_count := 0
	for entry in CharacterCatalogScript.get_character_entries():
		var entry_id := String(entry.get("id", ""))
		if not _should_include_owned_entry(owned_ids, entry_id):
			continue
		character_selector.add_item(String(entry.get("display_name", entry_id)))
		character_selector.set_item_metadata(character_selector.item_count - 1, entry_id)
		added_count += 1
	if added_count == 0:
		var fallback_id := _get_fallback_character_id()
		character_selector.add_item(fallback_id)
		character_selector.set_item_metadata(character_selector.item_count - 1, fallback_id)


func _populate_team_selector(team_option_max: int = 2) -> void:
	if team_selector == null:
		return
	team_selector.clear()
	var max_team_id: int = max(2, team_option_max)
	for team_id in range(1, max_team_id + 1):
		team_selector.add_item("Team %d" % team_id)
		team_selector.set_item_metadata(team_selector.item_count - 1, team_id)


func _populate_character_skin_selector() -> void:
	if character_skin_selector == null:
		return
	character_skin_selector.clear()
	character_skin_selector.add_item("None")
	character_skin_selector.set_item_metadata(0, "")
	var owned_ids := _get_owned_ids("character_skin")
	for skin_def in CharacterSkinCatalogScript.get_all():
		if skin_def == null:
			continue
		if not _should_include_owned_entry(owned_ids, String(skin_def.skin_id)):
			continue
		character_skin_selector.add_item(String(skin_def.display_name if not skin_def.display_name.is_empty() else skin_def.skin_id))
		character_skin_selector.set_item_metadata(character_skin_selector.item_count - 1, skin_def.skin_id)


func _populate_bubble_selector() -> void:
	if bubble_selector == null:
		return
	bubble_selector.clear()
	var owned_ids := _get_owned_ids("bubble")
	var added_count := 0
	for entry in BubbleCatalogScript.get_bubble_entries():
		var entry_id := String(entry.get("id", ""))
		if not _should_include_owned_entry(owned_ids, entry_id):
			continue
		bubble_selector.add_item(String(entry.get("display_name", entry_id)))
		bubble_selector.set_item_metadata(bubble_selector.item_count - 1, entry_id)
		added_count += 1
	if added_count == 0:
		var fallback_id := _get_fallback_bubble_id()
		bubble_selector.add_item(fallback_id)
		bubble_selector.set_item_metadata(bubble_selector.item_count - 1, fallback_id)


func _populate_bubble_skin_selector() -> void:
	if bubble_skin_selector == null:
		return
	bubble_skin_selector.clear()
	bubble_skin_selector.add_item("None")
	bubble_skin_selector.set_item_metadata(0, "")
	var owned_ids := _get_owned_ids("bubble_skin")
	for skin_def in BubbleSkinCatalogScript.get_all():
		if skin_def == null:
			continue
		if not _should_include_owned_entry(owned_ids, String(skin_def.bubble_skin_id)):
			continue
		bubble_skin_selector.add_item(String(skin_def.display_name if not skin_def.display_name.is_empty() else skin_def.bubble_skin_id))
		bubble_skin_selector.set_item_metadata(bubble_skin_selector.item_count - 1, skin_def.bubble_skin_id)


func _populate_map_selector(mode_id: String = "") -> void:
	if map_selector == null:
		return
	var current_value := _selected_metadata(map_selector)
	map_selector.clear()
	var resolved_mode_id := mode_id
	if resolved_mode_id.is_empty():
		resolved_mode_id = _selected_metadata(game_mode_selector)
	for entry in MapSelectionCatalogScript.get_custom_room_maps_by_mode(resolved_mode_id):
		map_selector.add_item(String(entry.get("display_name", entry.get("map_id", ""))))
		map_selector.set_item_metadata(map_selector.item_count - 1, String(entry.get("map_id", "")))
	_select_metadata(map_selector, current_value)


func _populate_mode_selector() -> void:
	if game_mode_selector == null:
		return
	var current_value := _selected_metadata(game_mode_selector)
	game_mode_selector.clear()
	for entry in MapSelectionCatalogScript.get_custom_room_mode_entries():
		game_mode_selector.add_item(String(entry.get("display_name", entry.get("mode_id", ""))))
		game_mode_selector.set_item_metadata(game_mode_selector.item_count - 1, String(entry.get("mode_id", "")))
	_select_metadata(game_mode_selector, current_value)


func _populate_match_format_selector(queue_type: String) -> void:
	if match_format_selector == null:
		return
	var current_value := _selected_metadata(match_format_selector)
	match_format_selector.clear()
	for entry in MapSelectionCatalogScript.get_match_room_format_entries(queue_type):
		var match_format_id := String(entry.get("match_format_id", entry.get("id", "")))
		var display_name := String(entry.get("display_name", match_format_id))
		var enabled := bool(entry.get("enabled", false))
		if not enabled:
			display_name += " (Locked)"
		match_format_selector.add_item(display_name)
		var index := match_format_selector.item_count - 1
		match_format_selector.set_item_metadata(index, match_format_id)
		match_format_selector.set_item_disabled(index, not enabled)
	_select_metadata(match_format_selector, current_value if not current_value.is_empty() else "1v1")


func _populate_match_mode_multi_select(queue_type: String, match_format_id: String, selected_mode_ids: Array[String] = []) -> void:
	if match_mode_multi_select == null:
		return
	match_mode_multi_select.clear()
	for entry in MapSelectionCatalogScript.get_match_room_mode_entries(queue_type, match_format_id):
		var mode_id := String(entry.get("mode_id", entry.get("id", "")))
		match_mode_multi_select.add_item(String(entry.get("display_name", mode_id)))
		var index := match_mode_multi_select.item_count - 1
		match_mode_multi_select.set_item_metadata(index, mode_id)
		if selected_mode_ids.has(mode_id) or selected_mode_ids.is_empty():
			match_mode_multi_select.select(index, false)
	_update_eligible_map_pool_hint(queue_type, match_format_id)


func _connect_ui_signals() -> void:
	if back_to_lobby_button != null and not back_to_lobby_button.pressed.is_connected(_on_back_to_lobby_pressed):
		back_to_lobby_button.pressed.connect(_on_back_to_lobby_pressed)
	if leave_room_button != null and not leave_room_button.pressed.is_connected(_on_leave_room_pressed):
		leave_room_button.pressed.connect(_on_leave_room_pressed)
	if ready_button != null and not ready_button.pressed.is_connected(_on_ready_button_pressed):
		ready_button.pressed.connect(_on_ready_button_pressed)
	if start_button != null and not start_button.pressed.is_connected(_on_start_button_pressed):
		start_button.pressed.connect(_on_start_button_pressed)
	if enter_queue_button != null and not enter_queue_button.pressed.is_connected(_on_enter_queue_button_pressed):
		enter_queue_button.pressed.connect(_on_enter_queue_button_pressed)
	if cancel_queue_button != null and not cancel_queue_button.pressed.is_connected(_on_cancel_queue_button_pressed):
		cancel_queue_button.pressed.connect(_on_cancel_queue_button_pressed)
	if copy_invite_code_button != null and not copy_invite_code_button.pressed.is_connected(_on_copy_invite_code_button_pressed):
		copy_invite_code_button.pressed.connect(_on_copy_invite_code_button_pressed)
	if add_opponent_button != null and not add_opponent_button.pressed.is_connected(_on_add_opponent_pressed):
		add_opponent_button.pressed.connect(_on_add_opponent_pressed)
	if player_name_input != null and not player_name_input.text_submitted.is_connected(_on_profile_changed):
		player_name_input.text_submitted.connect(func(_text: String) -> void: _on_profile_changed())
	if team_selector != null and not team_selector.item_selected.is_connected(_on_profile_selector_changed):
		team_selector.item_selected.connect(func(_index: int) -> void: _on_profile_selector_changed())
	if character_selector != null and not character_selector.item_selected.is_connected(_on_profile_selector_changed):
		character_selector.item_selected.connect(func(_index: int) -> void: _on_profile_selector_changed())
	if character_skin_selector != null and not character_skin_selector.item_selected.is_connected(_on_profile_selector_changed):
		character_skin_selector.item_selected.connect(func(_index: int) -> void: _on_profile_selector_changed())
	if bubble_selector != null and not bubble_selector.item_selected.is_connected(_on_profile_selector_changed):
		bubble_selector.item_selected.connect(func(_index: int) -> void: _on_profile_selector_changed())
	if bubble_skin_selector != null and not bubble_skin_selector.item_selected.is_connected(_on_profile_selector_changed):
		bubble_skin_selector.item_selected.connect(func(_index: int) -> void: _on_profile_selector_changed())
	if game_mode_selector != null and not game_mode_selector.item_selected.is_connected(_on_mode_selection_changed):
		game_mode_selector.item_selected.connect(func(_index: int) -> void: _on_mode_selection_changed())
	if map_selector != null and not map_selector.item_selected.is_connected(_on_selection_changed):
		map_selector.item_selected.connect(func(_index: int) -> void: _on_selection_changed())
	if match_format_selector != null and not match_format_selector.item_selected.is_connected(_on_match_format_changed):
		match_format_selector.item_selected.connect(func(_index: int) -> void: _on_match_format_changed())
	if match_mode_multi_select != null and not match_mode_multi_select.multi_selected.is_connected(_on_match_mode_multi_select_changed):
		match_mode_multi_select.multi_selected.connect(func(_index: int, _selected: bool) -> void: _on_match_mode_multi_select_changed())


func _connect_runtime_signals() -> void:
	if _room_controller == null:
		return
	if not _room_controller.room_snapshot_changed.is_connected(_on_room_snapshot_changed):
		_room_controller.room_snapshot_changed.connect(_on_room_snapshot_changed)
	if not _room_controller.start_match_requested.is_connected(_on_start_match_requested):
		_room_controller.start_match_requested.connect(_on_start_match_requested)


func _apply_local_profile_defaults() -> void:
	if _app_runtime == null or _app_runtime.player_profile_state == null:
		return
	var profile = _app_runtime.player_profile_state
	if player_name_input != null:
		player_name_input.text = profile.nickname
	_select_metadata(character_selector, profile.default_character_id)
	_select_team_id(1)
	_select_metadata(character_skin_selector, profile.default_character_skin_id)
	_select_metadata(bubble_selector, profile.default_bubble_style_id)
	_select_metadata(bubble_skin_selector, profile.default_bubble_skin_id)


func _refresh_room(snapshot: RoomSnapshot) -> void:
	if snapshot == null or _app_runtime == null or _room_view_model_builder == null or _room_scene_presenter == null:
		return
	var view_model := _room_view_model_builder.build_view_model(
		snapshot,
		_room_controller.room_runtime_context if _room_controller != null else null,
		_app_runtime.player_profile_state,
		_app_runtime.current_room_entry_context
	)
	_room_scene_presenter.present(view_model, self)
	_suppress_selection_callbacks = true
	_populate_team_selector(int(view_model.get("team_option_max", 2)))
	_select_team_id(int(view_model.get("local_team_id", 1)))
	if bool(view_model.get("is_match_room", false)):
		_populate_match_format_selector(String(snapshot.queue_type))
		_select_metadata(match_format_selector, String(snapshot.match_format_id))
		_populate_match_mode_multi_select(String(snapshot.queue_type), String(snapshot.match_format_id), snapshot.selected_match_mode_ids)
	else:
		_populate_mode_selector()
		_select_metadata(game_mode_selector, String(view_model.get("selected_mode_id", "")))
		_populate_map_selector(String(view_model.get("selected_mode_id", "")))
		_select_metadata(map_selector, String(view_model.get("selected_map_id", "")))
	_suppress_selection_callbacks = false
	_apply_room_kind_visibility(view_model)
	_refresh_match_room_controls(snapshot, view_model)
	_update_auth_binding_summary(snapshot)
	_update_preview(snapshot)
	_update_debug_text(snapshot, view_model)


func _update_preview(snapshot: RoomSnapshot) -> void:
	if snapshot == null:
		return
	if map_preview_label != null:
		map_preview_label.text = "Map: %s" % snapshot.selected_map_id
	if rule_preview_label != null:
		rule_preview_label.text = "Rule: %s" % snapshot.rule_set_id
	if mode_preview_label != null:
		mode_preview_label.text = "Mode: %s" % snapshot.mode_id
	var local_member := _resolve_local_member(snapshot)
	if local_member != null:
		if team_preview_label != null:
			team_preview_label.text = "Team: %d" % local_member.team_id
		if character_preview_label != null:
			character_preview_label.text = "Character: %s" % local_member.character_id
		if character_skin_preview_label != null:
			character_skin_preview_label.text = "Character Skin: %s" % local_member.character_skin_id
		if bubble_preview_label != null:
			bubble_preview_label.text = "Bubble: %s" % local_member.bubble_style_id
		if bubble_skin_preview_label != null:
			bubble_skin_preview_label.text = "Bubble Skin: %s" % local_member.bubble_skin_id
		if character_preview_viewport != null and character_preview_viewport.has_method("configure_preview"):
			character_preview_viewport.configure_preview(
				local_member.character_id,
				local_member.character_skin_id
			)
	elif _app_runtime != null and _app_runtime.player_profile_state != null:
		var profile = _app_runtime.player_profile_state
		if team_preview_label != null:
			team_preview_label.text = "Team: %d" % _selected_team_id()
		if character_preview_label != null:
			character_preview_label.text = "Character: %s" % String(profile.default_character_id)
		if character_skin_preview_label != null:
			character_skin_preview_label.text = "Character Skin: %s" % String(profile.default_character_skin_id)
		if bubble_preview_label != null:
			bubble_preview_label.text = "Bubble: %s" % String(profile.default_bubble_style_id)
		if bubble_skin_preview_label != null:
			bubble_skin_preview_label.text = "Bubble Skin: %s" % String(profile.default_bubble_skin_id)
		if character_preview_viewport != null and character_preview_viewport.has_method("configure_preview"):
			character_preview_viewport.configure_preview(
				_resolve_preview_character_id(String(profile.default_character_id)),
				_resolve_preview_character_skin_id(String(profile.default_character_skin_id))
			)


func _update_auth_binding_summary(snapshot: RoomSnapshot) -> void:
	if auth_binding_label == null:
		return
	var account_id := ""
	var profile_id := ""
	var member_id := ""
	var device_session_id := ""
	if _app_runtime != null and _app_runtime.current_room_entry_context != null:
		account_id = String(_app_runtime.current_room_entry_context.account_id)
		profile_id = String(_app_runtime.current_room_entry_context.profile_id)
		member_id = String(_app_runtime.current_room_entry_context.reconnect_member_id)
	if _app_runtime != null and _app_runtime.auth_session_state != null:
		if account_id.is_empty():
			account_id = String(_app_runtime.auth_session_state.account_id)
		if profile_id.is_empty():
			profile_id = String(_app_runtime.auth_session_state.profile_id)
		device_session_id = String(_app_runtime.auth_session_state.device_session_id)
	if member_id.is_empty() and _app_runtime != null and _app_runtime.front_settings_state != null:
		member_id = String(_app_runtime.front_settings_state.reconnect_member_id)
	var local_member := _resolve_local_member(snapshot)
	if member_id.is_empty() and local_member != null:
		member_id = "peer_%d" % int(local_member.peer_id)
	auth_binding_label.text = "Identity Binding:\naccount=%s\nprofile=%s\nmember=%s\nsession=%s" % [
		account_id if not account_id.is_empty() else "-",
		profile_id if not profile_id.is_empty() else "-",
		member_id if not member_id.is_empty() else "-",
		device_session_id if not device_session_id.is_empty() else "-",
	]


func _update_debug_text(snapshot: RoomSnapshot, view_model: Dictionary) -> void:
	if debug_label == null:
		return
	var lines := PackedStringArray()
	lines.append("Room: %s" % snapshot.room_id)
	lines.append("Kind: %s" % String(view_model.get("room_kind_text", "")))
	lines.append("Topology: %s" % String(view_model.get("topology_text", "")))
	lines.append("Map: %s" % snapshot.selected_map_id)
	lines.append("Rule: %s" % snapshot.rule_set_id)
	lines.append("Mode: %s" % snapshot.mode_id)
	lines.append("Owner: %s" % String(view_model.get("owner_text", "")))
	lines.append("Blocker: %s" % String(view_model.get("blocker_text", "")))
	debug_label.text = "\n".join(lines)


func _apply_room_kind_visibility(view_model: Dictionary) -> void:
	var room_kind := String(view_model.get("room_kind", ""))
	var is_custom_room := bool(view_model.get("is_custom_room", room_kind == "practice" or room_kind == "private_room" or room_kind == "public_room"))
	var is_match_room := bool(view_model.get("is_match_room", room_kind == "casual_match_room" or room_kind == "ranked_match_room"))
	var is_assigned_room := bool(view_model.get("is_assigned_room", room_kind == "matchmade_room"))
	_set_node_visible("RoomRoot/MainLayout/RoomSelectionCard/RoomSelectionVBox/MapRow", is_custom_room or is_assigned_room)
	_set_node_visible("RoomRoot/MainLayout/RoomSelectionCard/RoomSelectionVBox/RuleRow", is_custom_room or is_assigned_room)
	_set_node_visible("RoomRoot/MainLayout/RoomSelectionCard/RoomSelectionVBox/ModeRow", is_custom_room or is_assigned_room)
	_set_node_visible("RoomRoot/MainLayout/LocalLoadoutCard/LocalLoadoutVBox/TeamRow", is_custom_room)
	_set_node_visible("RoomRoot/MainLayout/RoomSelectionCard/RoomSelectionVBox/MatchFormatRow", is_match_room)
	_set_node_visible("RoomRoot/MainLayout/RoomSelectionCard/RoomSelectionVBox/MatchModeRow", is_match_room)
	_set_node_visible("RoomRoot/MainLayout/RoomSelectionCard/RoomSelectionVBox/InviteRow", is_match_room)
	_set_node_visible("RoomRoot/MainLayout/RoomSelectionCard/RoomSelectionVBox/QueueStatusRow", is_match_room)
	if start_button != null:
		start_button.visible = is_custom_room
	if enter_queue_button != null:
		enter_queue_button.visible = is_match_room
	if cancel_queue_button != null:
		cancel_queue_button.visible = is_match_room
	if ready_button != null:
		ready_button.visible = is_custom_room or is_match_room


func _refresh_match_room_controls(snapshot: RoomSnapshot, view_model: Dictionary) -> void:
	if snapshot == null:
		return
	if invite_code_value_label != null:
		invite_code_value_label.text = String(view_model.get("invite_code_text", snapshot.room_id))
	if queue_status_label != null:
		queue_status_label.text = String(view_model.get("queue_status_text", snapshot.room_queue_status_text))
	if queue_error_label != null:
		queue_error_label.text = String(view_model.get("queue_error_text", snapshot.room_queue_error_message))
	if enter_queue_button != null:
		enter_queue_button.disabled = not bool(view_model.get("can_enter_queue", false))
	if cancel_queue_button != null:
		cancel_queue_button.disabled = not bool(view_model.get("can_cancel_queue", false))
	_update_eligible_map_pool_hint(snapshot.queue_type, snapshot.match_format_id)


func _set_node_visible(path: String, visible: bool) -> void:
	var node := get_node_or_null(path)
	if node is CanvasItem:
		(node as CanvasItem).visible = visible


func _resolve_local_member(snapshot: RoomSnapshot) -> RoomMemberState:
	if snapshot == null or _app_runtime == null:
		return null
	for member in snapshot.members:
		if member != null and member.peer_id == int(_app_runtime.local_peer_id):
			return member
	return null


func _on_room_snapshot_changed(snapshot: RoomSnapshot) -> void:
	_refresh_room(snapshot)
	# Phase23: When battle_entry_ready becomes true, trigger battle entry flow
	if snapshot != null and snapshot.battle_entry_ready and _room_use_case != null and _front_flow != null:
		var battle_ctx = _room_use_case.build_battle_entry_context(snapshot)
		if battle_ctx != null and _app_runtime != null:
			_app_runtime.current_battle_entry_context = battle_ctx
			if _front_flow.has_method("request_battle_entry"):
				_front_flow.request_battle_entry()


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
	if _suppress_selection_callbacks or _room_use_case == null:
		return
	var snapshot: RoomSnapshot = _room_controller.build_room_snapshot() if _room_controller != null and _room_controller.has_method("build_room_snapshot") else null
	var local_member := _resolve_local_member(snapshot)
	if local_member != null and local_member.ready and _selected_team_id() != local_member.team_id:
		_select_team_id(local_member.team_id)
		_set_room_feedback("Team cannot be changed after ready")
		return
	_room_use_case.update_local_profile(
		player_name_input.text.strip_edges() if player_name_input != null else "",
		_selected_metadata(character_selector),
		_selected_metadata(character_skin_selector),
		_selected_metadata(bubble_selector),
		_selected_metadata(bubble_skin_selector),
		_selected_team_id()
	)


func _on_profile_selector_changed() -> void:
	if _suppress_selection_callbacks:
		return
	_on_profile_changed()


func _on_mode_selection_changed() -> void:
	if _suppress_selection_callbacks:
		return
	_suppress_selection_callbacks = true
	_populate_map_selector(_selected_metadata(game_mode_selector))
	if map_selector != null and map_selector.item_count > 0:
		map_selector.select(0)
	_suppress_selection_callbacks = false
	_on_selection_changed()


func _on_selection_changed() -> void:
	if _suppress_selection_callbacks or _room_use_case == null:
		return
	var snapshot: RoomSnapshot = _room_controller.build_room_snapshot() if _room_controller != null and _room_controller.has_method("build_room_snapshot") else null
	var map_id := _selected_metadata(map_selector)
	var binding := _resolve_map_binding(map_id)
	_log_room("room_selection_change_requested", {
		"old_map_id": String(snapshot.selected_map_id) if snapshot != null else "",
		"new_map_id": map_id,
		"derived_mode_id": String(binding.get("bound_mode_id", _selected_metadata(game_mode_selector))),
		"derived_rule_set_id": String(binding.get("bound_rule_set_id", "")),
	})
	var result := _room_use_case.update_selection(
		map_id,
		String(binding.get("bound_rule_set_id", "")),
		String(binding.get("bound_mode_id", _selected_metadata(game_mode_selector)))
	)
	if not bool(result.get("ok", false)):
		_set_room_feedback(String(result.get("user_message", "Failed to update room selection")))


func _on_match_format_changed() -> void:
	if _suppress_selection_callbacks:
		return
	var snapshot: RoomSnapshot = _room_controller.build_room_snapshot() if _room_controller != null and _room_controller.has_method("build_room_snapshot") else null
	var queue_type := String(snapshot.queue_type) if snapshot != null else "casual"
	var match_format_id := _selected_metadata(match_format_selector)
	_suppress_selection_callbacks = true
	_populate_match_mode_multi_select(queue_type, match_format_id)
	_suppress_selection_callbacks = false
	_on_match_mode_multi_select_changed()


func _on_match_mode_multi_select_changed() -> void:
	if _suppress_selection_callbacks or _room_use_case == null:
		return
	var result := _room_use_case.update_match_room_config(
		_selected_metadata(match_format_selector),
		_selected_match_mode_ids()
	)
	if not bool(result.get("ok", false)):
		_set_room_feedback(String(result.get("user_message", "Failed to update match room config")))


func _set_room_feedback(message: String) -> void:
	if blocker_label != null:
		blocker_label.text = message
	if debug_label != null:
		debug_label.text = message


func _selected_metadata(selector: OptionButton) -> String:
	if selector == null or selector.selected < 0:
		return ""
	return String(selector.get_item_metadata(selector.selected))


func _select_metadata(selector: OptionButton, value: String) -> void:
	if selector == null:
		return
	for index in range(selector.item_count):
		if String(selector.get_item_metadata(index)) == value:
			selector.select(index)
			return


func _selected_team_id() -> int:
	if team_selector == null or team_selector.selected < 0:
		return 1
	return int(team_selector.get_item_metadata(team_selector.selected))


func _select_team_id(team_id: int) -> void:
	if team_selector == null:
		return
	for index in range(team_selector.item_count):
		if int(team_selector.get_item_metadata(index)) == team_id:
			team_selector.select(index)
			return


func _selected_match_mode_ids() -> Array[String]:
	var result: Array[String] = []
	if match_mode_multi_select == null:
		return result
	for index in match_mode_multi_select.get_selected_items():
		result.append(String(match_mode_multi_select.get_item_metadata(index)))
	return result


func _update_eligible_map_pool_hint(queue_type: String, match_format_id: String) -> void:
	if eligible_map_pool_hint_label == null:
		return
	var selected_mode_ids := _selected_match_mode_ids()
	var count := MapSelectionCatalogScript.get_match_room_eligible_map_count(queue_type, match_format_id, selected_mode_ids)
	if count <= 0:
		eligible_map_pool_hint_label.text = "当前选择没有合法地图"
	else:
		eligible_map_pool_hint_label.text = "当前模式池可匹配 %d 张地图" % count


func _get_owned_ids(asset_type: String) -> Array[String]:
	if _app_runtime == null or _app_runtime.player_profile_state == null:
		return []
	var profile = _app_runtime.player_profile_state
	match asset_type:
		"character":
			return profile.owned_character_ids
		"character_skin":
			return profile.owned_character_skin_ids
		"bubble":
			return profile.owned_bubble_style_ids
		"bubble_skin":
			return profile.owned_bubble_skin_ids
		_:
			return []


func _should_include_owned_entry(owned_ids: Array[String], entry_id: String) -> bool:
	if owned_ids.is_empty():
		return false
	return owned_ids.has(entry_id)


func _get_fallback_character_id() -> String:
	if _app_runtime != null and _app_runtime.player_profile_state != null:
		var preferred_id := String(_app_runtime.player_profile_state.default_character_id)
		if not preferred_id.is_empty():
			return preferred_id
	for entry in CharacterCatalogScript.get_character_entries():
		var entry_id := String(entry.get("id", ""))
		if not entry_id.is_empty():
			return entry_id
	return "character_default"


func _get_fallback_bubble_id() -> String:
	if _app_runtime != null and _app_runtime.player_profile_state != null:
		var preferred_id := String(_app_runtime.player_profile_state.default_bubble_style_id)
		if not preferred_id.is_empty():
			return preferred_id
	for entry in BubbleCatalogScript.get_bubble_entries():
		var entry_id := String(entry.get("id", ""))
		if not entry_id.is_empty():
			return entry_id
	return "bubble_style_default"


func _resolve_preview_character_id(character_id: String) -> String:
	var trimmed := character_id.strip_edges()
	if not trimmed.is_empty() and CharacterCatalogScript.has_character(trimmed):
		return trimmed
	return CharacterCatalogScript.get_default_character_id()


func _resolve_preview_character_skin_id(character_skin_id: String) -> String:
	var trimmed := character_skin_id.strip_edges()
	if not trimmed.is_empty() and CharacterSkinCatalogScript.has_id(trimmed):
		return trimmed
	return CharacterSkinCatalogScript.get_default_skin_id()


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
