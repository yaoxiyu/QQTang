extends Node

const AppRuntimeRootScript = preload("res://app/flow/app_runtime_root.gd")
const LobbyRoomDirectoryBuilderScript = preload("res://app/front/lobby/lobby_room_directory_builder.gd")
const MapSelectionCatalogScript = preload("res://content/maps/catalog/map_selection_catalog.gd")
const LogFrontScript = preload("res://app/logging/log_front.gd")
const LOBBY_SCENE_LOG_PREFIX := "[QQT_LOBBY_SCENE]"
const ONLINE_LOG_PREFIX := "[QQT_ONLINE]"

@onready var lobby_root: Control = get_node_or_null("LobbyRoot")
@onready var main_layout: VBoxContainer = get_node_or_null("LobbyRoot/MainLayout")
@onready var header_row: HBoxContainer = get_node_or_null("LobbyRoot/MainLayout/HeaderRow")
@onready var title_label: Label = get_node_or_null("LobbyRoot/MainLayout/HeaderRow/TitleLabel")
@onready var scroll_area: ScrollContainer = get_node_or_null("LobbyRoot/MainLayout/ScrollArea")
@onready var scroll_content: VBoxContainer = get_node_or_null("LobbyRoot/MainLayout/ScrollArea/ScrollContent")
@onready var account_card: PanelContainer = get_node_or_null("LobbyRoot/MainLayout/ScrollArea/ScrollContent/AccountCard")
@onready var profile_card: PanelContainer = get_node_or_null("LobbyRoot/MainLayout/ScrollArea/ScrollContent/ProfileCard")
@onready var career_card: PanelContainer = get_node_or_null("LobbyRoot/MainLayout/ScrollArea/ScrollContent/CareerCard")
@onready var practice_card: PanelContainer = get_node_or_null("LobbyRoot/MainLayout/ScrollArea/ScrollContent/PracticeCard")
@onready var online_card: PanelContainer = get_node_or_null("LobbyRoot/MainLayout/ScrollArea/ScrollContent/OnlineCard")
@onready var match_room_entry_card: PanelContainer = get_node_or_null("LobbyRoot/MainLayout/ScrollArea/ScrollContent/MatchRoomEntryCard")
@onready var recent_card: PanelContainer = get_node_or_null("LobbyRoot/MainLayout/ScrollArea/ScrollContent/RecentCard")
@onready var current_profile_label: Label = get_node_or_null("LobbyRoot/MainLayout/HeaderRow/CurrentProfileLabel")
@onready var logout_button: Button = get_node_or_null("LobbyRoot/MainLayout/HeaderRow/LogoutButton")
@onready var shop_button: Button = get_node_or_null("LobbyRoot/MainLayout/HeaderRow/ShopButton")
@onready var inventory_button: Button = get_node_or_null("LobbyRoot/MainLayout/HeaderRow/InventoryButton")
@onready var account_id_value = get_node_or_null("LobbyRoot/MainLayout/ScrollArea/ScrollContent/AccountCard/AccountVBox/AccountIdRow/AccountIdValue")
@onready var profile_id_value = get_node_or_null("LobbyRoot/MainLayout/ScrollArea/ScrollContent/AccountCard/AccountVBox/ProfileIdRow/ProfileIdValue")
@onready var auth_mode_value = get_node_or_null("LobbyRoot/MainLayout/ScrollArea/ScrollContent/AccountCard/AccountVBox/AuthModeRow/AuthModeValue")
@onready var session_state_value = get_node_or_null("LobbyRoot/MainLayout/ScrollArea/ScrollContent/AccountCard/AccountVBox/SessionStateRow/SessionStateValue")
@onready var profile_sync_value = get_node_or_null("LobbyRoot/MainLayout/ScrollArea/ScrollContent/AccountCard/AccountVBox/ProfileSyncRow/ProfileSyncValue")
@onready var refresh_profile_button = get_node_or_null("LobbyRoot/MainLayout/ScrollArea/ScrollContent/AccountCard/AccountVBox/RefreshProfileButton")
@onready var wallet_summary_value: Label = get_node_or_null("LobbyRoot/MainLayout/ScrollArea/ScrollContent/AccountCard/AccountVBox/WalletSummaryRow/WalletSummaryValue")
@onready var inventory_status_value: Label = get_node_or_null("LobbyRoot/MainLayout/ScrollArea/ScrollContent/AccountCard/AccountVBox/InventoryStatusRow/InventoryStatusValue")
@onready var shop_status_value: Label = get_node_or_null("LobbyRoot/MainLayout/ScrollArea/ScrollContent/AccountCard/AccountVBox/ShopStatusRow/ShopStatusValue")
@onready var default_character_value: Label = get_node_or_null("LobbyRoot/MainLayout/ScrollArea/ScrollContent/ProfileCard/ProfileVBox/DefaultCharacterRow/DefaultCharacterValue")
@onready var default_character_skin_value: Label = get_node_or_null("LobbyRoot/MainLayout/ScrollArea/ScrollContent/ProfileCard/ProfileVBox/DefaultCharacterSkinRow/DefaultCharacterSkinValue")
@onready var default_bubble_value: Label = get_node_or_null("LobbyRoot/MainLayout/ScrollArea/ScrollContent/ProfileCard/ProfileVBox/DefaultBubbleRow/DefaultBubbleValue")
@onready var default_bubble_skin_value: Label = get_node_or_null("LobbyRoot/MainLayout/ScrollArea/ScrollContent/ProfileCard/ProfileVBox/DefaultBubbleSkinRow/DefaultBubbleSkinValue")
@onready var start_practice_button: Button = get_node_or_null("LobbyRoot/MainLayout/ScrollArea/ScrollContent/PracticeCard/PracticeVBox/StartPracticeButton")
@onready var host_input: LineEdit = get_node_or_null("LobbyRoot/MainLayout/ScrollArea/ScrollContent/OnlineCard/OnlineVBox/ServerRow/HostInput")
@onready var port_input: LineEdit = get_node_or_null("LobbyRoot/MainLayout/ScrollArea/ScrollContent/OnlineCard/OnlineVBox/ServerRow/PortInput")
@onready var room_id_input: LineEdit = get_node_or_null("LobbyRoot/MainLayout/ScrollArea/ScrollContent/OnlineCard/OnlineVBox/JoinRoomRow/RoomIdInput")
@onready var join_room_button: Button = get_node_or_null("LobbyRoot/MainLayout/ScrollArea/ScrollContent/OnlineCard/OnlineVBox/JoinRoomRow/JoinRoomButton")
@onready var connect_directory_button: Button = get_node_or_null("LobbyRoot/MainLayout/ScrollArea/ScrollContent/OnlineCard/OnlineVBox/DirectoryConnectionRow/ConnectDirectoryButton")
@onready var refresh_room_list_button: Button = get_node_or_null("LobbyRoot/MainLayout/ScrollArea/ScrollContent/OnlineCard/OnlineVBox/DirectoryConnectionRow/RefreshRoomListButton")
@onready var room_visibility_label: Label = get_node_or_null("LobbyRoot/MainLayout/ScrollArea/ScrollContent/OnlineCard/OnlineVBox/CustomRoomCreateRow/RoomVisibilityLabel")
@onready var room_visibility_selector: OptionButton = get_node_or_null("LobbyRoot/MainLayout/ScrollArea/ScrollContent/OnlineCard/OnlineVBox/CustomRoomCreateRow/RoomVisibilitySelector")
@onready var custom_room_name_label: Label = get_node_or_null("LobbyRoot/MainLayout/ScrollArea/ScrollContent/OnlineCard/OnlineVBox/CustomRoomCreateRow/CustomRoomNameLabel")
@onready var custom_room_name_input: LineEdit = get_node_or_null("LobbyRoot/MainLayout/ScrollArea/ScrollContent/OnlineCard/OnlineVBox/CustomRoomCreateRow/CustomRoomNameInput")
@onready var create_custom_room_button: Button = get_node_or_null("LobbyRoot/MainLayout/ScrollArea/ScrollContent/OnlineCard/OnlineVBox/CustomRoomCreateRow/CreateCustomRoomButton")
@onready var custom_room_mode_filter_label: Label = get_node_or_null("LobbyRoot/MainLayout/ScrollArea/ScrollContent/OnlineCard/OnlineVBox/CustomRoomFilterRow/CustomRoomModeFilterLabel")
@onready var custom_room_mode_filter_selector: OptionButton = get_node_or_null("LobbyRoot/MainLayout/ScrollArea/ScrollContent/OnlineCard/OnlineVBox/CustomRoomFilterRow/CustomRoomModeFilterSelector")
@onready var public_room_list: ItemList = get_node_or_null("LobbyRoot/MainLayout/ScrollArea/ScrollContent/OnlineCard/OnlineVBox/PublicRoomList")
@onready var join_selected_public_room_button: Button = get_node_or_null("LobbyRoot/MainLayout/ScrollArea/ScrollContent/OnlineCard/OnlineVBox/JoinSelectedPublicRoomButton")
@onready var directory_status_label: Label = get_node_or_null("LobbyRoot/MainLayout/ScrollArea/ScrollContent/OnlineCard/OnlineVBox/DirectoryStatusLabel")
@onready var recent_room_label: Label = get_node_or_null("LobbyRoot/MainLayout/ScrollArea/ScrollContent/RecentCard/RecentVBox/RecentRoomLabel")
@onready var recent_room_kind_label: Label = get_node_or_null("LobbyRoot/MainLayout/ScrollArea/ScrollContent/RecentCard/RecentVBox/RecentRoomKindLabel")
@onready var recent_room_display_name_label: Label = get_node_or_null("LobbyRoot/MainLayout/ScrollArea/ScrollContent/RecentCard/RecentVBox/RecentRoomDisplayNameLabel")
@onready var reconnect_match_label: Label = get_node_or_null("LobbyRoot/MainLayout/ScrollArea/ScrollContent/RecentCard/RecentVBox/ReconnectMatchLabel")
@onready var reconnect_state_label: Label = get_node_or_null("LobbyRoot/MainLayout/ScrollArea/ScrollContent/RecentCard/RecentVBox/ReconnectStateLabel")
@onready var reconnect_button: Button = get_node_or_null("LobbyRoot/MainLayout/ScrollArea/ScrollContent/RecentCard/RecentVBox/ReconnectButton")
@onready var current_season_value: Label = get_node_or_null("LobbyRoot/MainLayout/ScrollArea/ScrollContent/CareerCard/CareerVBox/CurrentSeasonRow/CurrentSeasonValue")
@onready var rating_value: Label = get_node_or_null("LobbyRoot/MainLayout/ScrollArea/ScrollContent/CareerCard/CareerVBox/RatingRow/RatingValue")
@onready var rank_tier_value: Label = get_node_or_null("LobbyRoot/MainLayout/ScrollArea/ScrollContent/CareerCard/CareerVBox/RankTierRow/RankTierValue")
@onready var total_matches_value: Label = get_node_or_null("LobbyRoot/MainLayout/ScrollArea/ScrollContent/CareerCard/CareerVBox/TotalMatchesRow/TotalMatchesValue")
@onready var wins_value: Label = get_node_or_null("LobbyRoot/MainLayout/ScrollArea/ScrollContent/CareerCard/CareerVBox/WinsRow/WinsValue")
@onready var win_rate_value: Label = get_node_or_null("LobbyRoot/MainLayout/ScrollArea/ScrollContent/CareerCard/CareerVBox/WinRateRow/WinRateValue")
@onready var last_match_value: Label = get_node_or_null("LobbyRoot/MainLayout/ScrollArea/ScrollContent/CareerCard/CareerVBox/LastMatchRow/LastMatchValue")
@onready var refresh_career_button: Button = get_node_or_null("LobbyRoot/MainLayout/ScrollArea/ScrollContent/CareerCard/CareerVBox/RefreshCareerButton")
@onready var create_casual_match_room_button: Button = get_node_or_null("LobbyRoot/MainLayout/ScrollArea/ScrollContent/MatchRoomEntryCard/MatchRoomEntryVBox/CasualMatchRoomRow/CreateCasualMatchRoomButton")
@onready var create_ranked_match_room_button: Button = get_node_or_null("LobbyRoot/MainLayout/ScrollArea/ScrollContent/MatchRoomEntryCard/MatchRoomEntryVBox/RankedMatchRoomRow/CreateRankedMatchRoomButton")
@onready var match_room_hint_label: Label = get_node_or_null("LobbyRoot/MainLayout/ScrollArea/ScrollContent/MatchRoomEntryCard/MatchRoomEntryVBox/MatchRoomHintLabel")
@onready var message_label: Label = get_node_or_null("LobbyRoot/MainLayout/ScrollArea/ScrollContent/MessageLabel")

var _app_runtime: Node = null
var _room_directory_builder = LobbyRoomDirectoryBuilderScript.new()
var _last_room_directory_snapshot = null
var _directory_connect_requested: bool = false
var _queue_assignment_consuming: bool = false


func _ready() -> void:
	_apply_formal_lobby_layout()
	_bind_runtime()


func _bind_runtime() -> void:
	_app_runtime = AppRuntimeRootScript.get_existing(get_tree())
	if _app_runtime == null:
		_set_message("Runtime missing, returning to boot...")
		_redirect_to_boot_if_missing()
		return
	if _app_runtime.has_method("is_runtime_ready") and _app_runtime.is_runtime_ready():
		_on_runtime_ready()
		return
	if _app_runtime.has_signal("runtime_ready") and not _app_runtime.runtime_ready.is_connected(_on_runtime_ready):
		_app_runtime.runtime_ready.connect(_on_runtime_ready, CONNECT_ONE_SHOT)


func _on_runtime_ready() -> void:
	_refresh_account_node_refs()
	_ensure_phase34_entry_buttons()
	_ensure_phase34_summary_rows()
	_apply_phase34_lobby_asset_ids()
	_populate_practice_selectors()
	_configure_custom_room_controls()
	_populate_custom_room_mode_filter()
	_refresh_view()
	_connect_signals()
	_log_online_lobby("runtime_ready", _build_online_debug_context())


func _redirect_to_boot_if_missing() -> void:
	if _app_runtime != null and _app_runtime.front_flow != null and _app_runtime.front_flow.has_method("enter_boot"):
		_app_runtime.front_flow.enter_boot()
		return
	get_tree().change_scene_to_file("res://scenes/front/boot_scene.tscn")


func _populate_practice_selectors() -> void:
	return


func _configure_custom_room_controls() -> void:
	if room_visibility_label != null:
		room_visibility_label.text = "房间可见性"
	if custom_room_name_label != null:
		custom_room_name_label.text = "自定义房间名"
	if custom_room_name_input != null:
		custom_room_name_input.placeholder_text = "公开房间必填"
	if create_custom_room_button != null:
		create_custom_room_button.text = "创建自定义房间"
	if join_selected_public_room_button != null:
		join_selected_public_room_button.text = "加入自定义房间"
	if custom_room_mode_filter_label != null:
		custom_room_mode_filter_label.text = "玩法筛选"
	if room_visibility_selector == null:
		return
	var current_value := _selected_metadata(room_visibility_selector)
	room_visibility_selector.clear()
	room_visibility_selector.add_item("Private")
	room_visibility_selector.set_item_metadata(0, "private")
	room_visibility_selector.add_item("Public")
	room_visibility_selector.set_item_metadata(1, "public")
	_select_metadata(room_visibility_selector, current_value if not current_value.is_empty() else "private")


func _populate_custom_room_mode_filter() -> void:
	if custom_room_mode_filter_selector == null:
		return
	custom_room_mode_filter_selector.clear()
	custom_room_mode_filter_selector.add_item("All")
	custom_room_mode_filter_selector.set_item_metadata(0, "")
	for entry in MapSelectionCatalogScript.get_custom_room_mode_entries():
		var mode_id := String(entry.get("mode_id", ""))
		custom_room_mode_filter_selector.add_item(String(entry.get("display_name", mode_id)))
		custom_room_mode_filter_selector.set_item_metadata(custom_room_mode_filter_selector.item_count - 1, mode_id)
	if custom_room_mode_filter_selector.item_count > 0:
		custom_room_mode_filter_selector.select(0)


func _refresh_view() -> void:
	if _app_runtime == null or _app_runtime.lobby_use_case == null:
		return
	var result: Dictionary = _app_runtime.lobby_use_case.enter_lobby()
	var view_state = result.get("view_state", null)
	if view_state == null:
		return
	if current_profile_label != null:
		current_profile_label.text = String(view_state.profile_name)
	if account_id_value != null:
		account_id_value.text = String(view_state.account_id if not String(view_state.account_id).is_empty() else "-")
	if profile_id_value != null:
		profile_id_value.text = String(view_state.profile_id if not String(view_state.profile_id).is_empty() else "-")
	if auth_mode_value != null:
		auth_mode_value.text = String(view_state.auth_mode if not String(view_state.auth_mode).is_empty() else "-")
	if session_state_value != null:
		session_state_value.text = String(view_state.session_state if not String(view_state.session_state).is_empty() else "-")
	if profile_sync_value != null:
		var sync_text := "-"
		if int(view_state.last_sync_msec) > 0:
			sync_text = "%s @ %d" % [String(view_state.profile_source if not String(view_state.profile_source).is_empty() else "cache"), int(view_state.last_sync_msec)]
		profile_sync_value.text = sync_text
	if wallet_summary_value != null:
		wallet_summary_value.text = String(view_state.wallet_summary_text if not String(view_state.wallet_summary_text).is_empty() else "-")
	if inventory_status_value != null:
		inventory_status_value.text = String(view_state.inventory_status_text if not String(view_state.inventory_status_text).is_empty() else "-")
	if shop_status_value != null:
		shop_status_value.text = String(view_state.shop_status_text if not String(view_state.shop_status_text).is_empty() else "-")
	if default_character_value != null:
		default_character_value.text = String(view_state.default_character_id)
	if default_character_skin_value != null:
		default_character_skin_value.text = String(view_state.default_character_skin_id)
	if default_bubble_value != null:
		default_bubble_value.text = String(view_state.default_bubble_style_id)
	if default_bubble_skin_value != null:
		default_bubble_skin_value.text = String(view_state.default_bubble_skin_id)
	if host_input != null:
		host_input.text = String(view_state.last_server_host)
	if port_input != null:
		port_input.text = str(int(view_state.last_server_port))
	if room_id_input != null:
		room_id_input.text = String(view_state.last_room_id)
	if recent_room_label != null:
		var room_id_text := String(view_state.reconnect_room_id if not String(view_state.reconnect_room_id).is_empty() else view_state.last_room_id)
		var room_kind_text := String(view_state.reconnect_room_kind)
		var room_display_name_text := String(view_state.reconnect_room_display_name)
		if not room_kind_text.is_empty():
			recent_room_label.text = "Recent Room [%s]: %s (%s)" % [room_kind_text, room_display_name_text if not room_display_name_text.is_empty() else room_id_text, room_id_text]
		else:
			recent_room_label.text = "Recent Room: %s" % room_id_text
	if recent_room_kind_label != null:
		recent_room_kind_label.text = "Kind: %s" % (String(view_state.reconnect_room_kind) if not String(view_state.reconnect_room_kind).is_empty() else "-")
	if recent_room_display_name_label != null:
		recent_room_display_name_label.text = "Name: %s" % (String(view_state.reconnect_room_display_name) if not String(view_state.reconnect_room_display_name).is_empty() else "-")
	if reconnect_match_label != null:
		var match_id := String(view_state.reconnect_match_id)
		if not match_id.is_empty():
			reconnect_match_label.text = "Match: %s" % match_id
		else:
			reconnect_match_label.text = "Match: -"
	if reconnect_state_label != null:
		var reconnect_state := String(view_state.reconnect_state)
		if not reconnect_state.is_empty():
			reconnect_state_label.text = "Reconnect State: %s" % reconnect_state
		else:
			reconnect_state_label.text = "Reconnect State: -"
	_refresh_career_panel(view_state)
	if match_room_hint_label != null:
		match_room_hint_label.text = "进入匹配房间后再选择几v几与模式池，队伍准备完成后再开始匹配。"
	_set_message("")
	_log_online_lobby("refresh_view", _build_online_debug_context())


func _refresh_career_panel(view_state = null) -> void:
	if view_state == null and _app_runtime != null and _app_runtime.lobby_use_case != null:
		view_state = _app_runtime.lobby_use_case.enter_lobby(false).get("view_state", null)
	if view_state == null:
		return
	if current_season_value != null:
		current_season_value.text = String(view_state.current_season_id if not String(view_state.current_season_id).is_empty() else "-")
	if rating_value != null:
		rating_value.text = str(int(view_state.current_rating))
	if rank_tier_value != null:
		rank_tier_value.text = String(view_state.current_rank_tier if not String(view_state.current_rank_tier).is_empty() else "-")
	if total_matches_value != null:
		total_matches_value.text = str(int(view_state.career_total_matches))
	if wins_value != null:
		wins_value.text = "%d / L%d / D%d" % [
			int(view_state.career_total_wins),
			int(view_state.career_total_losses),
			int(view_state.career_total_draws),
		]
	if win_rate_value != null:
		win_rate_value.text = "%.1f%%" % (float(int(view_state.career_win_rate_bp)) / 100.0)
	if last_match_value != null:
		var last_match_text := "-"
		if _app_runtime != null and _app_runtime.career_use_case != null and _app_runtime.career_use_case.has_method("get_current_summary"):
			var summary = _app_runtime.career_use_case.get_current_summary()
			if summary != null:
				var match_id := String(summary.last_match_id)
				var outcome := String(summary.last_match_outcome)
				if not match_id.is_empty() or not outcome.is_empty():
					last_match_text = "%s%s" % [
						outcome if not outcome.is_empty() else "Unknown",
						" (%s)" % match_id if not match_id.is_empty() else "",
					]
		last_match_value.text = last_match_text


func _connect_signals() -> void:
	if start_practice_button != null and not start_practice_button.pressed.is_connected(_on_start_practice_pressed):
		start_practice_button.pressed.connect(_on_start_practice_pressed)
	if create_custom_room_button != null and not create_custom_room_button.pressed.is_connected(_on_create_custom_room_pressed):
		create_custom_room_button.pressed.connect(_on_create_custom_room_pressed)
	if join_room_button != null and not join_room_button.pressed.is_connected(_on_join_room_pressed):
		join_room_button.pressed.connect(_on_join_room_pressed)
	if reconnect_button != null and not reconnect_button.pressed.is_connected(_on_reconnect_pressed):
		reconnect_button.pressed.connect(_on_reconnect_pressed)
	if logout_button != null and not logout_button.pressed.is_connected(_on_logout_pressed):
		logout_button.pressed.connect(_on_logout_pressed)
	if shop_button != null and not shop_button.pressed.is_connected(_on_shop_pressed):
		shop_button.pressed.connect(_on_shop_pressed)
	if inventory_button != null and not inventory_button.pressed.is_connected(_on_inventory_pressed):
		inventory_button.pressed.connect(_on_inventory_pressed)
	if refresh_profile_button != null and not refresh_profile_button.pressed.is_connected(_on_refresh_profile_pressed):
		refresh_profile_button.pressed.connect(_on_refresh_profile_pressed)
	if refresh_career_button != null and not refresh_career_button.pressed.is_connected(_on_refresh_career_pressed):
		refresh_career_button.pressed.connect(_on_refresh_career_pressed)
	if connect_directory_button != null and not connect_directory_button.pressed.is_connected(_on_connect_directory_pressed):
		connect_directory_button.pressed.connect(_on_connect_directory_pressed)
	if refresh_room_list_button != null and not refresh_room_list_button.pressed.is_connected(_on_refresh_room_list_pressed):
		refresh_room_list_button.pressed.connect(_on_refresh_room_list_pressed)
	if join_selected_public_room_button != null and not join_selected_public_room_button.pressed.is_connected(_on_join_selected_public_room_pressed):
		join_selected_public_room_button.pressed.connect(_on_join_selected_public_room_pressed)
	if custom_room_mode_filter_selector != null and not custom_room_mode_filter_selector.item_selected.is_connected(_on_custom_room_mode_filter_changed):
		custom_room_mode_filter_selector.item_selected.connect(func(_index: int) -> void: _on_custom_room_mode_filter_changed())
	if create_casual_match_room_button != null and not create_casual_match_room_button.pressed.is_connected(_on_create_casual_match_room_pressed):
		create_casual_match_room_button.pressed.connect(_on_create_casual_match_room_pressed)
	if create_ranked_match_room_button != null and not create_ranked_match_room_button.pressed.is_connected(_on_create_ranked_match_room_pressed):
		create_ranked_match_room_button.pressed.connect(_on_create_ranked_match_room_pressed)
	if _app_runtime != null and _app_runtime.client_room_runtime != null and not _app_runtime.client_room_runtime.room_error.is_connected(_on_room_error):
		_app_runtime.client_room_runtime.room_error.connect(_on_room_error)
	if _app_runtime != null and _app_runtime.client_room_runtime != null and not _app_runtime.client_room_runtime.transport_connected.is_connected(_on_transport_connected):
		_app_runtime.client_room_runtime.transport_connected.connect(_on_transport_connected)
	if _app_runtime != null and _app_runtime.client_room_runtime != null and _app_runtime.client_room_runtime.has_signal("room_directory_snapshot_received") and not _app_runtime.client_room_runtime.room_directory_snapshot_received.is_connected(_on_room_directory_snapshot_received):
		_app_runtime.client_room_runtime.room_directory_snapshot_received.connect(_on_room_directory_snapshot_received)


func _on_start_practice_pressed() -> void:
	if _app_runtime == null or _app_runtime.lobby_use_case == null or _app_runtime.room_use_case == null:
		_set_message("Lobby room flow is not available.")
		return
	var result: Dictionary = _app_runtime.lobby_use_case.start_practice("", "", "")
	_handle_room_entry_result(result)


func _on_create_custom_room_pressed() -> void:
	if _app_runtime == null or _app_runtime.lobby_use_case == null or _app_runtime.room_use_case == null:
		_set_message("Lobby room flow is not available.")
		return
	var visibility := _selected_metadata(room_visibility_selector)
	var default_map_id := MapSelectionCatalogScript.get_default_custom_room_map_id()
	var default_binding := MapSelectionCatalogScript.get_map_binding(default_map_id)
	_log_lobby_scene("custom_room_create_requested", {
		"visibility": visibility,
		"default_map_id": default_map_id,
		"derived_mode_id": String(default_binding.get("bound_mode_id", "")),
		"derived_rule_set_id": String(default_binding.get("bound_rule_set_id", "")),
		"room_display_name": custom_room_name_input.text.strip_edges() if custom_room_name_input != null else "",
	})
	var result: Dictionary = _app_runtime.lobby_use_case.create_custom_room(
		host_input.text.strip_edges() if host_input != null else "",
		int(port_input.text.to_int()) if port_input != null else 0,
		visibility,
		custom_room_name_input.text.strip_edges() if custom_room_name_input != null else ""
	)
	_handle_room_entry_result(result)


func _on_create_casual_match_room_pressed() -> void:
	if _app_runtime == null or _app_runtime.lobby_use_case == null or _app_runtime.room_use_case == null:
		_set_message("Lobby room flow is not available.")
		return
	var result: Dictionary = _app_runtime.lobby_use_case.create_casual_match_room(
		host_input.text.strip_edges() if host_input != null else "",
		int(port_input.text.to_int()) if port_input != null else 0
	)
	_handle_room_entry_result(result)


func _on_create_ranked_match_room_pressed() -> void:
	if _app_runtime == null or _app_runtime.lobby_use_case == null or _app_runtime.room_use_case == null:
		_set_message("Lobby room flow is not available.")
		return
	var result: Dictionary = _app_runtime.lobby_use_case.create_ranked_match_room(
		host_input.text.strip_edges() if host_input != null else "",
		int(port_input.text.to_int()) if port_input != null else 0
	)
	_handle_room_entry_result(result)


func _on_join_room_pressed() -> void:
	if _app_runtime == null or _app_runtime.lobby_use_case == null or _app_runtime.room_use_case == null:
		_set_message("Lobby room flow is not available.")
		return
	var result: Dictionary = _app_runtime.lobby_use_case.join_private_room(
		host_input.text.strip_edges() if host_input != null else "",
		int(port_input.text.to_int()) if port_input != null else 0,
		room_id_input.text.strip_edges() if room_id_input != null else ""
	)
	_handle_room_entry_result(result)


func _on_connect_directory_pressed() -> void:
	if _app_runtime == null or _app_runtime.lobby_directory_use_case == null:
		_set_directory_status("Directory flow is not available.")
		return
	_directory_connect_requested = true
	_log_lobby_scene("ui_connect_directory_pressed", {
		"host": host_input.text.strip_edges() if host_input != null else "",
		"port": int(port_input.text.to_int()) if port_input != null else 0,
	})
	var result: Dictionary = _app_runtime.lobby_directory_use_case.connect_directory(
		host_input.text.strip_edges() if host_input != null else "",
		int(port_input.text.to_int()) if port_input != null else 0
	)
	_apply_directory_result(result)


func _on_refresh_room_list_pressed() -> void:
	if _app_runtime == null or _app_runtime.lobby_directory_use_case == null:
		_set_directory_status("Directory flow is not available.")
		return
	_directory_connect_requested = true
	_log_lobby_scene("ui_refresh_room_list_pressed", {
		"host": host_input.text.strip_edges() if host_input != null else "",
		"port": int(port_input.text.to_int()) if port_input != null else 0,
	})
	var result: Dictionary = _app_runtime.lobby_directory_use_case.refresh_directory(
		host_input.text.strip_edges() if host_input != null else "",
		int(port_input.text.to_int()) if port_input != null else 0
	)
	_apply_directory_result(result)


func _on_join_selected_public_room_pressed() -> void:
	if public_room_list == null or public_room_list.get_selected_items().is_empty():
		_set_directory_status("Select a custom room first.")
		return
	if _app_runtime == null or _app_runtime.lobby_use_case == null or _app_runtime.room_use_case == null:
		_set_directory_status("Lobby room flow is not available.")
		return
	var selected_index := int(public_room_list.get_selected_items()[0])
	var room_id := String(public_room_list.get_item_metadata(selected_index))
	_log_lobby_scene("ui_join_selected_public_room_pressed", {
		"room_id": room_id,
		"selected_index": selected_index,
	})
	var result: Dictionary = _app_runtime.lobby_use_case.join_public_room(
		host_input.text.strip_edges() if host_input != null else "",
		int(port_input.text.to_int()) if port_input != null else 0,
		room_id
	)
	_handle_room_entry_result(result)


func _on_custom_room_mode_filter_changed() -> void:
	_refresh_directory_list()


func _on_reconnect_pressed() -> void:
	if _app_runtime == null or _app_runtime.lobby_use_case == null or _app_runtime.room_use_case == null:
		_set_message("Lobby room flow is not available.")
		return
	var result: Dictionary = _app_runtime.lobby_use_case.resume_recent_room()
	_handle_room_entry_result(result)


func _on_logout_pressed() -> void:
	if _app_runtime == null or _app_runtime.lobby_use_case == null:
		return
	_app_runtime.lobby_use_case.logout()
	if _app_runtime.front_flow != null and _app_runtime.front_flow.has_method("enter_login"):
		_app_runtime.front_flow.enter_login()


func _on_shop_pressed() -> void:
	if _app_runtime != null and _app_runtime.front_flow != null and _app_runtime.front_flow.has_method("enter_shop"):
		_app_runtime.front_flow.enter_shop()


func _on_inventory_pressed() -> void:
	if _app_runtime != null and _app_runtime.front_flow != null and _app_runtime.front_flow.has_method("enter_inventory"):
		_app_runtime.front_flow.enter_inventory()


func _ensure_phase34_entry_buttons() -> void:
	if header_row == null:
		return
	if shop_button == null:
		shop_button = Button.new()
		shop_button.name = "ShopButton"
		shop_button.text = "Shop"
		header_row.add_child(shop_button)
	if inventory_button == null:
		inventory_button = Button.new()
		inventory_button.name = "InventoryButton"
		inventory_button.text = "Inventory"
		header_row.add_child(inventory_button)


func _ensure_phase34_summary_rows() -> void:
	var account_vbox: VBoxContainer = get_node_or_null("LobbyRoot/MainLayout/ScrollArea/ScrollContent/AccountCard/AccountVBox")
	if account_vbox == null:
		return
	if wallet_summary_value == null:
		wallet_summary_value = _create_summary_row(account_vbox, "WalletSummaryRow", "Wallet")
	if inventory_status_value == null:
		inventory_status_value = _create_summary_row(account_vbox, "InventoryStatusRow", "Inventory")
	if shop_status_value == null:
		shop_status_value = _create_summary_row(account_vbox, "ShopStatusRow", "Shop")


func _create_summary_row(parent: VBoxContainer, row_name: String, label_text: String) -> Label:
	var row := HBoxContainer.new()
	row.name = row_name
	parent.add_child(row)
	var label := Label.new()
	label.text = label_text
	row.add_child(label)
	var value := Label.new()
	value.name = "%sValue" % label_text.replace(" ", "")
	value.text = "-"
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(value)
	return value


func _apply_formal_lobby_layout() -> void:
	_reparent_account_card_children()
	_refresh_account_node_refs()
	_ensure_lobby_background()
	if main_layout != null:
		main_layout.set_anchors_preset(Control.PRESET_FULL_RECT)
		main_layout.offset_left = 56.0
		main_layout.offset_top = 40.0
		main_layout.offset_right = -56.0
		main_layout.offset_bottom = -36.0
		main_layout.add_theme_constant_override("separation", 18)
	if header_row != null:
		header_row.add_theme_constant_override("separation", 10)
	if title_label != null:
		title_label.text = "QQTang Lobby"
		title_label.add_theme_font_size_override("font_size", 28)
	if current_profile_label != null:
		current_profile_label.add_theme_font_size_override("font_size", 18)
	if scroll_area != null:
		scroll_area.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	if scroll_content != null:
		scroll_content.custom_minimum_size = Vector2(0, 0)
		scroll_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll_content.add_theme_constant_override("separation", 14)
	for card in [account_card, profile_card, career_card, practice_card, online_card, match_room_entry_card, recent_card]:
		_apply_lobby_card_style(card)
	for button in [
		logout_button,
		shop_button,
		inventory_button,
		refresh_profile_button,
		refresh_career_button,
		start_practice_button,
		join_room_button,
		connect_directory_button,
		refresh_room_list_button,
		join_selected_public_room_button,
		create_casual_match_room_button,
		create_ranked_match_room_button,
		reconnect_button,
	]:
		_apply_lobby_button_style(button)
	_apply_phase34_lobby_asset_ids()


func _reparent_account_card_children() -> void:
	if account_card == null:
		return
	var account_vbox: VBoxContainer = account_card.get_node_or_null("AccountVBox")
	if account_vbox == null:
		account_vbox = VBoxContainer.new()
		account_vbox.name = "AccountVBox"
		account_card.add_child(account_vbox)
	account_vbox.add_theme_constant_override("separation", 8)
	var children := account_card.get_children()
	for child in children:
		if child == account_vbox:
			continue
		account_card.remove_child(child)
		account_vbox.add_child(child)


func _refresh_account_node_refs() -> void:
	account_id_value = get_node_or_null("LobbyRoot/MainLayout/ScrollArea/ScrollContent/AccountCard/AccountVBox/AccountIdRow/AccountIdValue")
	profile_id_value = get_node_or_null("LobbyRoot/MainLayout/ScrollArea/ScrollContent/AccountCard/AccountVBox/ProfileIdRow/ProfileIdValue")
	auth_mode_value = get_node_or_null("LobbyRoot/MainLayout/ScrollArea/ScrollContent/AccountCard/AccountVBox/AuthModeRow/AuthModeValue")
	session_state_value = get_node_or_null("LobbyRoot/MainLayout/ScrollArea/ScrollContent/AccountCard/AccountVBox/SessionStateRow/SessionStateValue")
	profile_sync_value = get_node_or_null("LobbyRoot/MainLayout/ScrollArea/ScrollContent/AccountCard/AccountVBox/ProfileSyncRow/ProfileSyncValue")
	refresh_profile_button = get_node_or_null("LobbyRoot/MainLayout/ScrollArea/ScrollContent/AccountCard/AccountVBox/RefreshProfileButton")
	wallet_summary_value = get_node_or_null("LobbyRoot/MainLayout/ScrollArea/ScrollContent/AccountCard/AccountVBox/WalletSummaryRow/WalletSummaryValue")
	inventory_status_value = get_node_or_null("LobbyRoot/MainLayout/ScrollArea/ScrollContent/AccountCard/AccountVBox/InventoryStatusRow/InventoryStatusValue")
	shop_status_value = get_node_or_null("LobbyRoot/MainLayout/ScrollArea/ScrollContent/AccountCard/AccountVBox/ShopStatusRow/ShopStatusValue")


func _ensure_lobby_background() -> void:
	if lobby_root == null:
		return
	var background: ColorRect = lobby_root.get_node_or_null("FormalBackground")
	if background == null:
		background = ColorRect.new()
		background.name = "FormalBackground"
		lobby_root.add_child(background)
		lobby_root.move_child(background, 0)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.06, 0.10, 0.14, 1.0)
	background.set_meta("ui_asset_id", "ui.lobby.bg.main")


func _apply_lobby_card_style(card: PanelContainer) -> void:
	if card == null:
		return
	card.add_theme_stylebox_override("panel", _make_lobby_style(Color(0.12, 0.17, 0.22, 0.94), Color(0.30, 0.43, 0.56, 0.7), 8))
	card.set_meta("ui_asset_id", "ui.lobby.panel.player_summary")


func _apply_lobby_button_style(button: Button) -> void:
	if button == null:
		return
	button.custom_minimum_size = Vector2(max(button.custom_minimum_size.x, 112.0), 38.0)
	button.add_theme_stylebox_override("normal", _make_lobby_style(Color(0.23, 0.31, 0.39, 1.0), Color(0.42, 0.58, 0.72, 0.8), 6))
	button.add_theme_stylebox_override("hover", _make_lobby_style(Color(0.30, 0.40, 0.50, 1.0), Color(0.58, 0.76, 0.92, 1.0), 6))
	button.add_theme_stylebox_override("pressed", _make_lobby_style(Color(0.16, 0.22, 0.29, 1.0), Color(0.54, 0.70, 0.86, 1.0), 6))


func _apply_phase34_lobby_asset_ids() -> void:
	_set_lobby_asset_meta(lobby_root, "ui.lobby.bg.main")
	_set_lobby_asset_meta(account_card, "ui.lobby.panel.player_summary")
	_set_lobby_asset_meta(shop_button, "ui.lobby.button.shop.normal")
	_set_lobby_asset_meta(inventory_button, "ui.lobby.button.inventory.normal")


func _make_lobby_style(color: Color, border_color: Color, radius: int) -> StyleBoxFlat:
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


func _set_lobby_asset_meta(node: Node, asset_id: String) -> void:
	if node == null:
		return
	node.set_meta("ui_asset_id", asset_id)


func _on_refresh_profile_pressed() -> void:
	if _app_runtime == null or _app_runtime.lobby_use_case == null:
		_set_message("Profile refresh is not available.")
		return
	var result: Dictionary = _app_runtime.lobby_use_case.refresh_profile()
	if not bool(result.get("ok", false)):
		_set_message(String(result.get("user_message", "Profile refresh failed")))
		return
	_refresh_view()


func _on_refresh_career_pressed() -> void:
	if _app_runtime == null or _app_runtime.career_use_case == null:
		_set_message("Career refresh is not available.")
		return
	var result: Dictionary = _app_runtime.career_use_case.refresh_career_summary()
	if not bool(result.get("ok", false)):
		_log_online_lobby("refresh_career_failed", result)
		_set_message(String(result.get("user_message", "Career refresh failed")))
		return
	_refresh_view()
	_log_online_lobby("refresh_career_succeeded", _build_online_debug_context())


func _on_enter_queue_pressed() -> void:
	# LEGACY: formal flow enters queue from match rooms, not Lobby.
	_log_online_lobby("enter_queue_blocked_room_required", _build_online_debug_context())
	_set_message("Create or join a room first, ready the room, then enter matchmaking from the room.")
	_set_directory_status("Create or join a room first.")


func _on_cancel_queue_pressed() -> void:
	# LEGACY: formal flow cancels queue from match rooms, not Lobby.
	_set_message("Cancel matchmaking from the match room.")
	_log_online_lobby("cancel_queue_succeeded", _build_online_debug_context())


func _handle_room_entry_result(result: Dictionary) -> void:
	if not bool(result.get("ok", false)):
		_queue_assignment_consuming = false
		_log_online_lobby("room_entry_failed", result)
		_set_message(String(result.get("user_message", "Room entry failed")))
		_set_directory_status(String(result.get("user_message", "")))
		return
	var entry_context: Variant = result.get("entry_context", null)
	if entry_context == null:
		_queue_assignment_consuming = false
		_log_online_lobby("room_entry_missing_context", result)
		_set_message("Room entry context is missing.")
		_set_directory_status("Room entry context is missing.")
		return
	_log_lobby_scene("room_entry_context_ready", {
		"entry_kind": String(entry_context.entry_kind),
		"room_kind": String(entry_context.room_kind),
		"target_room_id": String(entry_context.target_room_id),
		"room_display_name": String(entry_context.room_display_name),
		"assignment_id": String(entry_context.assignment_id),
		"assigned_map_id": String(entry_context.locked_map_id),
		"assigned_rule_set_id": String(entry_context.locked_rule_set_id),
		"assigned_mode_id": String(entry_context.locked_mode_id),
		"assigned_team_id": int(entry_context.assigned_team_id),
	})
	_directory_connect_requested = false
	if _app_runtime != null and _app_runtime.client_room_runtime != null and _app_runtime.client_room_runtime.has_method("unsubscribe_room_directory"):
		_app_runtime.client_room_runtime.unsubscribe_room_directory()
	var room_result: Dictionary = _app_runtime.room_use_case.enter_room(entry_context)
	if not bool(room_result.get("ok", false)):
		_queue_assignment_consuming = false
		_log_online_lobby("room_use_case_enter_failed", room_result)
		_set_message(String(room_result.get("user_message", "Failed to enter room")))
		_set_directory_status(String(room_result.get("user_message", "")))
		return
	if bool(room_result.get("pending", false)):
		_log_online_lobby("room_entry_pending", _build_online_debug_context())
		_set_message("Connecting...")
		_set_directory_status("")
		return
	_set_message("")
	_set_directory_status("")
	_log_online_lobby("room_entry_completed", _build_online_debug_context())


func front_settings_state_available() -> bool:
	return _app_runtime != null and _app_runtime.front_settings_state != null


func _selected_metadata(selector: OptionButton) -> String:
	if selector == null or selector.selected < 0:
		return ""
	return String(selector.get_item_metadata(selector.selected))


func _select_metadata(selector: OptionButton, target: String) -> void:
	if selector == null:
		return
	for index in range(selector.item_count):
		if String(selector.get_item_metadata(index)) == target:
			selector.select(index)
			return
	if selector.item_count > 0:
		selector.select(0)


func _set_message(text: String) -> void:
	if message_label != null:
		message_label.text = text


func _set_directory_status(text: String) -> void:
	if directory_status_label != null:
		directory_status_label.text = text


func _on_room_error(_error_code: String, user_message: String) -> void:
	if _app_runtime == null or _app_runtime.front_flow == null:
		return
	if _app_runtime.front_flow.get_state_name() != &"LOBBY":
		return
	_set_message(user_message)
	_set_directory_status(user_message)
	_log_online_lobby("room_error", {
		"user_message": user_message,
		"context": _build_online_debug_context(),
	})


func _on_transport_connected() -> void:
	if not _directory_connect_requested:
		return
	if _app_runtime == null or _app_runtime.front_flow == null or _app_runtime.lobby_directory_use_case == null:
		return
	if _app_runtime.front_flow.get_state_name() != &"LOBBY":
		return
	var result: Dictionary = _app_runtime.lobby_directory_use_case.refresh_directory(
		host_input.text.strip_edges() if host_input != null else "",
		int(port_input.text.to_int()) if port_input != null else 0
	)
	_apply_directory_result(result)


func _apply_directory_result(result: Dictionary) -> void:
	if not bool(result.get("ok", false)):
		_set_directory_status(String(result.get("user_message", "Directory request failed")))
		return
	_set_directory_status(String(result.get("user_message", "")))


func _on_room_directory_snapshot_received(snapshot) -> void:
	_last_room_directory_snapshot = snapshot.duplicate_deep() if snapshot != null and snapshot.has_method("duplicate_deep") else snapshot
	_refresh_directory_list()


func _refresh_directory_list() -> void:
	if public_room_list == null:
		return
	public_room_list.clear()
	var snapshot = _last_room_directory_snapshot
	if snapshot == null:
		_set_directory_status("No custom rooms available.")
		return
	var view_models := _room_directory_builder.build_view_models(snapshot)
	var filtered_mode_id := _selected_metadata(custom_room_mode_filter_selector)
	var rendered_count := 0
	for view_model in view_models:
		var room_kind := String(view_model.get("room_kind", ""))
		if room_kind != "public_room" and room_kind != "custom_room":
			continue
		var mode_id := String(view_model.get("mode_id", ""))
		if not filtered_mode_id.is_empty() and mode_id != filtered_mode_id:
			continue
		var label_text := String(view_model.get("summary_text", view_model.get("room_display_name", "")))
		public_room_list.add_item(label_text)
		public_room_list.set_item_metadata(public_room_list.item_count - 1, String(view_model.get("room_id", "")))
		rendered_count += 1
	_set_directory_status("Loaded %d custom room(s)." % rendered_count)


func _log_lobby_scene(event_name: String, payload: Dictionary) -> void:
	LogFrontScript.debug("%s[lobby_scene] %s %s" % [LOBBY_SCENE_LOG_PREFIX, event_name, JSON.stringify(payload)], "", 0, "front.lobby.scene")


func _log_online_lobby(event_name: String, payload: Dictionary) -> void:
	LogFrontScript.debug("%s[lobby_scene] %s %s" % [ONLINE_LOG_PREFIX, event_name, JSON.stringify(payload)], "", 0, "front.lobby.online")


func _with_debug_payload(base_payload: Dictionary, extra_payload: Dictionary) -> Dictionary:
	var payload := base_payload.duplicate(true)
	for key in extra_payload.keys():
		payload[key] = extra_payload[key]
	return payload


func _build_online_debug_context() -> Dictionary:
	var queue_state = null
	var assignment_state = null
	if _app_runtime != null and _app_runtime.matchmaking_use_case != null:
		if _app_runtime.matchmaking_use_case.has_method("get_queue_state"):
			queue_state = _app_runtime.matchmaking_use_case.get_queue_state()
		if _app_runtime.matchmaking_use_case.has_method("get_assignment_state"):
			assignment_state = _app_runtime.matchmaking_use_case.get_assignment_state()
	return {
		"flow_state": _app_runtime.front_flow.get_state_name() if _app_runtime != null and _app_runtime.front_flow != null else &"",
		"queue_state": queue_state.queue_state if queue_state != null else "",
		"queue_entry_id": queue_state.queue_entry_id if queue_state != null else "",
		"assignment_id": assignment_state.assignment_id if assignment_state != null else "",
		"assignment_room_id": assignment_state.room_id if assignment_state != null else "",
		"assignment_ticket_role": assignment_state.ticket_role if assignment_state != null else "",
		"queue_assignment_consuming": _queue_assignment_consuming,
	}
