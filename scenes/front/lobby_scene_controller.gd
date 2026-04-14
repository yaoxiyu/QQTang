extends Node

const AppRuntimeRootScript = preload("res://app/flow/app_runtime_root.gd")
const LobbyRoomDirectoryBuilderScript = preload("res://app/front/lobby/lobby_room_directory_builder.gd")
const MapCatalogScript = preload("res://content/maps/catalog/map_catalog.gd")
const ModeCatalogScript = preload("res://content/modes/catalog/mode_catalog.gd")
const RuleSetCatalogScript = preload("res://content/rulesets/catalog/rule_set_catalog.gd")
const LogFrontScript = preload("res://app/logging/log_front.gd")
const PHASE15_LOG_PREFIX := "[QQT_P15]"
const ONLINE_LOG_PREFIX := "[QQT_ONLINE]"
const MATCHMAKING_POLL_INTERVAL_SEC := 2.0

@onready var current_profile_label: Label = get_node_or_null("LobbyRoot/MainLayout/HeaderRow/CurrentProfileLabel")
@onready var logout_button: Button = get_node_or_null("LobbyRoot/MainLayout/HeaderRow/LogoutButton")
@onready var account_id_value = get_node_or_null("LobbyRoot/MainLayout/ScrollArea/ScrollContent/AccountCard/AccountVBox/AccountIdRow/AccountIdValue")
@onready var profile_id_value = get_node_or_null("LobbyRoot/MainLayout/ScrollArea/ScrollContent/AccountCard/AccountVBox/ProfileIdRow/ProfileIdValue")
@onready var auth_mode_value = get_node_or_null("LobbyRoot/MainLayout/ScrollArea/ScrollContent/AccountCard/AccountVBox/AuthModeRow/AuthModeValue")
@onready var session_state_value = get_node_or_null("LobbyRoot/MainLayout/ScrollArea/ScrollContent/AccountCard/AccountVBox/SessionStateRow/SessionStateValue")
@onready var profile_sync_value = get_node_or_null("LobbyRoot/MainLayout/ScrollArea/ScrollContent/AccountCard/AccountVBox/ProfileSyncRow/ProfileSyncValue")
@onready var refresh_profile_button = get_node_or_null("LobbyRoot/MainLayout/ScrollArea/ScrollContent/AccountCard/AccountVBox/RefreshProfileButton")
@onready var default_character_value: Label = get_node_or_null("LobbyRoot/MainLayout/ScrollArea/ScrollContent/ProfileCard/ProfileVBox/DefaultCharacterRow/DefaultCharacterValue")
@onready var default_character_skin_value: Label = get_node_or_null("LobbyRoot/MainLayout/ScrollArea/ScrollContent/ProfileCard/ProfileVBox/DefaultCharacterSkinRow/DefaultCharacterSkinValue")
@onready var default_bubble_value: Label = get_node_or_null("LobbyRoot/MainLayout/ScrollArea/ScrollContent/ProfileCard/ProfileVBox/DefaultBubbleRow/DefaultBubbleValue")
@onready var default_bubble_skin_value: Label = get_node_or_null("LobbyRoot/MainLayout/ScrollArea/ScrollContent/ProfileCard/ProfileVBox/DefaultBubbleSkinRow/DefaultBubbleSkinValue")
@onready var practice_map_selector: OptionButton = get_node_or_null("LobbyRoot/MainLayout/ScrollArea/ScrollContent/PracticeCard/PracticeVBox/PracticeMapRow/PracticeMapSelector")
@onready var practice_rule_selector: OptionButton = get_node_or_null("LobbyRoot/MainLayout/ScrollArea/ScrollContent/PracticeCard/PracticeVBox/PracticeRuleRow/PracticeRuleSelector")
@onready var practice_mode_selector: OptionButton = get_node_or_null("LobbyRoot/MainLayout/ScrollArea/ScrollContent/PracticeCard/PracticeVBox/PracticeModeRow/PracticeModeSelector")
@onready var start_practice_button: Button = get_node_or_null("LobbyRoot/MainLayout/ScrollArea/ScrollContent/PracticeCard/PracticeVBox/StartPracticeButton")
@onready var host_input: LineEdit = get_node_or_null("LobbyRoot/MainLayout/ScrollArea/ScrollContent/OnlineCard/OnlineVBox/ServerRow/HostInput")
@onready var port_input: LineEdit = get_node_or_null("LobbyRoot/MainLayout/ScrollArea/ScrollContent/OnlineCard/OnlineVBox/ServerRow/PortInput")
@onready var create_room_button: Button = get_node_or_null("LobbyRoot/MainLayout/ScrollArea/ScrollContent/OnlineCard/OnlineVBox/CreateRoomRow/CreateRoomButton")
@onready var room_id_input: LineEdit = get_node_or_null("LobbyRoot/MainLayout/ScrollArea/ScrollContent/OnlineCard/OnlineVBox/JoinRoomRow/RoomIdInput")
@onready var join_room_button: Button = get_node_or_null("LobbyRoot/MainLayout/ScrollArea/ScrollContent/OnlineCard/OnlineVBox/JoinRoomRow/JoinRoomButton")
@onready var connect_directory_button: Button = get_node_or_null("LobbyRoot/MainLayout/ScrollArea/ScrollContent/OnlineCard/OnlineVBox/DirectoryConnectionRow/ConnectDirectoryButton")
@onready var refresh_room_list_button: Button = get_node_or_null("LobbyRoot/MainLayout/ScrollArea/ScrollContent/OnlineCard/OnlineVBox/DirectoryConnectionRow/RefreshRoomListButton")
@onready var public_room_name_input: LineEdit = get_node_or_null("LobbyRoot/MainLayout/ScrollArea/ScrollContent/OnlineCard/OnlineVBox/CreatePublicRoomRow/PublicRoomNameInput")
@onready var create_public_room_button: Button = get_node_or_null("LobbyRoot/MainLayout/ScrollArea/ScrollContent/OnlineCard/OnlineVBox/CreatePublicRoomRow/CreatePublicRoomButton")
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
@onready var game_service_host_input: LineEdit = get_node_or_null("LobbyRoot/MainLayout/ScrollArea/ScrollContent/MatchmakingCard/MatchmakingVBox/GameServiceRow/GameServiceHostInput")
@onready var game_service_port_input: LineEdit = get_node_or_null("LobbyRoot/MainLayout/ScrollArea/ScrollContent/MatchmakingCard/MatchmakingVBox/GameServiceRow/GameServicePortInput")
@onready var queue_type_selector: OptionButton = get_node_or_null("LobbyRoot/MainLayout/ScrollArea/ScrollContent/MatchmakingCard/MatchmakingVBox/QueueTypeRow/QueueTypeSelector")
@onready var queue_mode_selector: OptionButton = get_node_or_null("LobbyRoot/MainLayout/ScrollArea/ScrollContent/MatchmakingCard/MatchmakingVBox/QueueModeRow/QueueModeSelector")
@onready var queue_rule_selector: OptionButton = get_node_or_null("LobbyRoot/MainLayout/ScrollArea/ScrollContent/MatchmakingCard/MatchmakingVBox/QueueRuleRow/QueueRuleSelector")
@onready var enter_queue_button: Button = get_node_or_null("LobbyRoot/MainLayout/ScrollArea/ScrollContent/MatchmakingCard/MatchmakingVBox/QueueActionRow/EnterQueueButton")
@onready var cancel_queue_button: Button = get_node_or_null("LobbyRoot/MainLayout/ScrollArea/ScrollContent/MatchmakingCard/MatchmakingVBox/QueueActionRow/CancelQueueButton")
@onready var queue_status_label: Label = get_node_or_null("LobbyRoot/MainLayout/ScrollArea/ScrollContent/MatchmakingCard/MatchmakingVBox/QueueStatusLabel")
@onready var assignment_summary_label: Label = get_node_or_null("LobbyRoot/MainLayout/ScrollArea/ScrollContent/MatchmakingCard/MatchmakingVBox/AssignmentSummaryLabel")
@onready var message_label: Label = get_node_or_null("LobbyRoot/MainLayout/ScrollArea/ScrollContent/MessageLabel")

var _app_runtime: Node = null
var _room_directory_builder = LobbyRoomDirectoryBuilderScript.new()
var _last_room_directory_snapshot = null
var _directory_connect_requested: bool = false
var _queue_poll_timer: Timer = null
var _queue_assignment_consuming: bool = false


func _ready() -> void:
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
	_populate_practice_selectors()
	_populate_matchmaking_selectors()
	_refresh_view()
	_connect_signals()
	_ensure_matchmaking_poll_timer()
	_log_online_lobby("runtime_ready", _build_online_debug_context())


func _redirect_to_boot_if_missing() -> void:
	if _app_runtime != null and _app_runtime.front_flow != null and _app_runtime.front_flow.has_method("enter_boot"):
		_app_runtime.front_flow.enter_boot()
		return
	get_tree().change_scene_to_file("res://scenes/front/boot_scene.tscn")


func _populate_practice_selectors() -> void:
	if practice_map_selector != null:
		practice_map_selector.clear()
		for entry in MapCatalogScript.get_map_entries():
			practice_map_selector.add_item(String(entry.get("display_name", entry.get("id", ""))))
			practice_map_selector.set_item_metadata(practice_map_selector.item_count - 1, String(entry.get("id", "")))
	if practice_rule_selector != null:
		practice_rule_selector.clear()
		for entry in RuleSetCatalogScript.get_rule_entries():
			practice_rule_selector.add_item(String(entry.get("display_name", entry.get("id", ""))))
			practice_rule_selector.set_item_metadata(practice_rule_selector.item_count - 1, String(entry.get("id", "")))
	if practice_mode_selector != null:
		practice_mode_selector.clear()
		for entry in ModeCatalogScript.get_mode_entries():
			practice_mode_selector.add_item(String(entry.get("display_name", entry.get("id", ""))))
			practice_mode_selector.set_item_metadata(practice_mode_selector.item_count - 1, String(entry.get("id", "")))


func _populate_matchmaking_selectors() -> void:
	if queue_type_selector != null:
		queue_type_selector.clear()
		queue_type_selector.add_item("Casual")
		queue_type_selector.set_item_metadata(0, "casual")
		queue_type_selector.add_item("Ranked")
		queue_type_selector.set_item_metadata(1, "ranked")
	if queue_mode_selector != null:
		queue_mode_selector.clear()
		for entry in ModeCatalogScript.get_mode_entries():
			var mode_id := String(entry.get("mode_id", entry.get("id", "")))
			queue_mode_selector.add_item(String(entry.get("display_name", mode_id)))
			queue_mode_selector.set_item_metadata(queue_mode_selector.item_count - 1, mode_id)
	if queue_rule_selector != null:
		queue_rule_selector.clear()
		for entry in RuleSetCatalogScript.get_rule_entries():
			queue_rule_selector.add_item(String(entry.get("display_name", entry.get("id", ""))))
			queue_rule_selector.set_item_metadata(queue_rule_selector.item_count - 1, String(entry.get("id", "")))


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
	_select_metadata(practice_map_selector, String(view_state.preferred_map_id))
	_select_metadata(practice_rule_selector, String(view_state.preferred_rule_id))
	_select_metadata(practice_mode_selector, String(view_state.preferred_mode_id))
	_refresh_career_panel(view_state)
	_refresh_matchmaking_panel(view_state)
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


func _refresh_matchmaking_panel(view_state = null) -> void:
	if front_settings_state_available():
		if game_service_host_input != null:
			game_service_host_input.text = String(_app_runtime.front_settings_state.game_service_host)
		if game_service_port_input != null:
			game_service_port_input.text = str(int(_app_runtime.front_settings_state.game_service_port))
	if view_state == null and _app_runtime != null and _app_runtime.lobby_use_case != null:
		view_state = _app_runtime.lobby_use_case.enter_lobby(false).get("view_state", null)
	if view_state == null:
		return
	var queue_type := String(view_state.queue_type if not String(view_state.queue_type).is_empty() else (_app_runtime.front_settings_state.last_queue_type if front_settings_state_available() else "casual"))
	_select_metadata(queue_type_selector, queue_type)
	_select_metadata(queue_mode_selector, String(view_state.preferred_mode_id))
	_select_metadata(queue_rule_selector, String(view_state.preferred_rule_id))
	if queue_status_label != null:
		var queue_state_text := String(view_state.queue_state)
		var queue_status_text := String(view_state.queue_status_text)
		if queue_status_text.is_empty():
			queue_status_text = "Idle" if queue_state_text.is_empty() else queue_state_text.capitalize()
		queue_status_label.text = "Queue: %s" % queue_status_text
	if assignment_summary_label != null:
		var assignment_status_text := String(view_state.assignment_status_text)
		if String(view_state.assignment_id).is_empty():
			assignment_summary_label.text = "Assignment: -"
		else:
			assignment_summary_label.text = "Assignment: %s%s" % [
				String(view_state.assignment_id),
				" | %s" % assignment_status_text if not assignment_status_text.is_empty() else "",
			]
	if enter_queue_button != null:
		var queue_state := String(view_state.queue_state)
		enter_queue_button.disabled = queue_state == "queued" or queue_state == "assigned" or queue_state == "committing"
	if cancel_queue_button != null:
		cancel_queue_button.disabled = String(view_state.queue_state).is_empty() or String(view_state.queue_state) == "cancelled"


func _connect_signals() -> void:
	if start_practice_button != null and not start_practice_button.pressed.is_connected(_on_start_practice_pressed):
		start_practice_button.pressed.connect(_on_start_practice_pressed)
	if create_room_button != null and not create_room_button.pressed.is_connected(_on_create_room_pressed):
		create_room_button.pressed.connect(_on_create_room_pressed)
	if join_room_button != null and not join_room_button.pressed.is_connected(_on_join_room_pressed):
		join_room_button.pressed.connect(_on_join_room_pressed)
	if reconnect_button != null and not reconnect_button.pressed.is_connected(_on_reconnect_pressed):
		reconnect_button.pressed.connect(_on_reconnect_pressed)
	if logout_button != null and not logout_button.pressed.is_connected(_on_logout_pressed):
		logout_button.pressed.connect(_on_logout_pressed)
	if refresh_profile_button != null and not refresh_profile_button.pressed.is_connected(_on_refresh_profile_pressed):
		refresh_profile_button.pressed.connect(_on_refresh_profile_pressed)
	if refresh_career_button != null and not refresh_career_button.pressed.is_connected(_on_refresh_career_pressed):
		refresh_career_button.pressed.connect(_on_refresh_career_pressed)
	if connect_directory_button != null and not connect_directory_button.pressed.is_connected(_on_connect_directory_pressed):
		connect_directory_button.pressed.connect(_on_connect_directory_pressed)
	if refresh_room_list_button != null and not refresh_room_list_button.pressed.is_connected(_on_refresh_room_list_pressed):
		refresh_room_list_button.pressed.connect(_on_refresh_room_list_pressed)
	if create_public_room_button != null and not create_public_room_button.pressed.is_connected(_on_create_public_room_pressed):
		create_public_room_button.pressed.connect(_on_create_public_room_pressed)
	if join_selected_public_room_button != null and not join_selected_public_room_button.pressed.is_connected(_on_join_selected_public_room_pressed):
		join_selected_public_room_button.pressed.connect(_on_join_selected_public_room_pressed)
	if enter_queue_button != null and not enter_queue_button.pressed.is_connected(_on_enter_queue_pressed):
		enter_queue_button.pressed.connect(_on_enter_queue_pressed)
	if cancel_queue_button != null and not cancel_queue_button.pressed.is_connected(_on_cancel_queue_pressed):
		cancel_queue_button.pressed.connect(_on_cancel_queue_pressed)
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
	var result: Dictionary = _app_runtime.lobby_use_case.start_practice(
		_selected_metadata(practice_map_selector),
		_selected_metadata(practice_rule_selector),
		_selected_metadata(practice_mode_selector)
	)
	_handle_room_entry_result(result)


func _on_create_room_pressed() -> void:
	if _app_runtime == null or _app_runtime.lobby_use_case == null or _app_runtime.room_use_case == null:
		_set_message("Lobby room flow is not available.")
		return
	var result: Dictionary = _app_runtime.lobby_use_case.create_private_room(
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
	_log_phase15("ui_connect_directory_pressed", {
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
	_log_phase15("ui_refresh_room_list_pressed", {
		"host": host_input.text.strip_edges() if host_input != null else "",
		"port": int(port_input.text.to_int()) if port_input != null else 0,
	})
	var result: Dictionary = _app_runtime.lobby_directory_use_case.refresh_directory(
		host_input.text.strip_edges() if host_input != null else "",
		int(port_input.text.to_int()) if port_input != null else 0
	)
	_apply_directory_result(result)


func _on_create_public_room_pressed() -> void:
	if _app_runtime == null or _app_runtime.lobby_use_case == null or _app_runtime.room_use_case == null:
		_set_directory_status("Lobby room flow is not available.")
		return
	_log_phase15("ui_create_public_room_pressed", {
		"host": host_input.text.strip_edges() if host_input != null else "",
		"port": int(port_input.text.to_int()) if port_input != null else 0,
		"room_display_name": public_room_name_input.text.strip_edges() if public_room_name_input != null else "",
	})
	var result: Dictionary = _app_runtime.lobby_use_case.create_public_room(
		host_input.text.strip_edges() if host_input != null else "",
		int(port_input.text.to_int()) if port_input != null else 0,
		public_room_name_input.text.strip_edges() if public_room_name_input != null else ""
	)
	_handle_room_entry_result(result)


func _on_join_selected_public_room_pressed() -> void:
	if public_room_list == null or public_room_list.get_selected_items().is_empty():
		_set_directory_status("Select a public room first.")
		return
	if _app_runtime == null or _app_runtime.lobby_use_case == null or _app_runtime.room_use_case == null:
		_set_directory_status("Lobby room flow is not available.")
		return
	var selected_index := int(public_room_list.get_selected_items()[0])
	var room_id := String(public_room_list.get_item_metadata(selected_index))
	_log_phase15("ui_join_selected_public_room_pressed", {
		"room_id": room_id,
		"selected_index": selected_index,
	})
	var result: Dictionary = _app_runtime.lobby_use_case.join_public_room(
		host_input.text.strip_edges() if host_input != null else "",
		int(port_input.text.to_int()) if port_input != null else 0,
		room_id
	)
	_handle_room_entry_result(result)


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
	if _app_runtime == null or _app_runtime.matchmaking_use_case == null or _app_runtime.lobby_use_case == null:
		_set_message("Matchmaking flow is not available.")
		return
	_queue_assignment_consuming = false
	_save_matchmaking_settings()
	var result: Dictionary = _app_runtime.matchmaking_use_case.enter_queue(
		_selected_metadata(queue_type_selector),
		_selected_metadata(queue_mode_selector),
		_selected_metadata(queue_rule_selector)
	)
	if not bool(result.get("ok", false)):
		_log_online_lobby("enter_queue_failed", result)
		if String(result.get("error_code", "")) == "MATCHMAKING_QUEUE_ALREADY_ACTIVE":
			var status_result: Dictionary = _app_runtime.matchmaking_use_case.poll_queue_status()
			if bool(status_result.get("ok", false)):
				var view_state = _app_runtime.lobby_use_case.enter_lobby(false).get("view_state", null)
				_refresh_matchmaking_panel(view_state)
			_set_message("Existing active queue detected. Cancel it first or wait for assignment.")
		else:
			_set_message(String(result.get("user_message", "Failed to enter queue")))
		_refresh_matchmaking_panel()
		return
	_refresh_view()
	_set_message("Queue entered, searching for players...")
	_log_online_lobby("enter_queue_succeeded", _build_online_debug_context())


func _on_cancel_queue_pressed() -> void:
	if _app_runtime == null or _app_runtime.matchmaking_use_case == null:
		_set_message("Matchmaking flow is not available.")
		return
	var result: Dictionary = _app_runtime.matchmaking_use_case.cancel_queue()
	if not bool(result.get("ok", false)):
		_log_online_lobby("cancel_queue_failed", result)
		_set_message(String(result.get("user_message", "Failed to cancel queue")))
		return
	_queue_assignment_consuming = false
	_refresh_view()
	_set_message("Queue cancelled.")
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
	_log_phase15("room_entry_context_ready", {
		"entry_kind": String(entry_context.entry_kind),
		"room_kind": String(entry_context.room_kind),
		"target_room_id": String(entry_context.target_room_id),
		"room_display_name": String(entry_context.room_display_name),
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


func _poll_queue_status() -> void:
	if _queue_assignment_consuming:
		return
	if _app_runtime == null or _app_runtime.matchmaking_use_case == null or _app_runtime.front_flow == null:
		return
	if _app_runtime.front_flow.get_state_name() != &"LOBBY":
		return
	var queue_state = _app_runtime.matchmaking_use_case.get_queue_state() if _app_runtime.matchmaking_use_case.has_method("get_queue_state") else null
	if queue_state == null or String(queue_state.queue_state).is_empty():
		return
	var status_result: Dictionary = _app_runtime.matchmaking_use_case.poll_queue_status()
	if not bool(status_result.get("ok", false)):
		_log_online_lobby("poll_queue_status_failed", status_result)
		_set_message(String(status_result.get("user_message", "Matchmaking status refresh failed")))
		_refresh_matchmaking_panel()
		return
	var view_state = _app_runtime.lobby_use_case.enter_lobby(false).get("view_state", null) if _app_runtime.lobby_use_case != null else null
	_refresh_matchmaking_panel(view_state)
	var assignment_state = status_result.get("assignment_state", null)
	if assignment_state == null or String(assignment_state.assignment_id).is_empty():
		return
	_log_online_lobby("assignment_detected", {
		"assignment_id": String(assignment_state.assignment_id),
		"ticket_role": String(assignment_state.ticket_role),
		"room_id": String(assignment_state.room_id),
	})
	_queue_assignment_consuming = true
	var entry_result: Dictionary = _app_runtime.lobby_use_case.build_matchmade_entry_context()
	if not bool(entry_result.get("ok", false)):
		_queue_assignment_consuming = false
		_log_online_lobby("build_matchmade_entry_context_failed", entry_result)
		_set_message(String(entry_result.get("user_message", "Failed to consume match assignment")))
		_refresh_matchmaking_panel()
		return
	_handle_room_entry_result(entry_result)


func _ensure_matchmaking_poll_timer() -> void:
	if _queue_poll_timer != null and is_instance_valid(_queue_poll_timer):
		return
	_queue_poll_timer = Timer.new()
	_queue_poll_timer.name = "MatchmakingPollTimer"
	_queue_poll_timer.wait_time = MATCHMAKING_POLL_INTERVAL_SEC
	_queue_poll_timer.one_shot = false
	_queue_poll_timer.autostart = true
	add_child(_queue_poll_timer)
	if not _queue_poll_timer.timeout.is_connected(_poll_queue_status):
		_queue_poll_timer.timeout.connect(_poll_queue_status)
	_queue_poll_timer.start()


func _save_matchmaking_settings() -> void:
	if not front_settings_state_available():
		return
	_app_runtime.front_settings_state.game_service_host = game_service_host_input.text.strip_edges() if game_service_host_input != null else _app_runtime.front_settings_state.game_service_host
	_app_runtime.front_settings_state.game_service_port = int(game_service_port_input.text.to_int()) if game_service_port_input != null and game_service_port_input.text.to_int() > 0 else _app_runtime.front_settings_state.game_service_port
	_app_runtime.front_settings_state.last_queue_type = _selected_metadata(queue_type_selector)
	if _app_runtime.front_settings_repository != null and _app_runtime.front_settings_repository.has_method("save_settings"):
		_app_runtime.front_settings_repository.save_settings(_app_runtime.front_settings_state)


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


func _exit_tree() -> void:
	if _queue_poll_timer != null and is_instance_valid(_queue_poll_timer):
		if _queue_poll_timer.timeout.is_connected(_poll_queue_status):
			_queue_poll_timer.timeout.disconnect(_poll_queue_status)
		_queue_poll_timer.stop()


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
	if public_room_list == null:
		return
	public_room_list.clear()
	if snapshot == null:
		_set_directory_status("No public rooms available.")
		return
	var view_models := _room_directory_builder.build_view_models(snapshot)
	_log_phase15("ui_room_directory_snapshot_render", {
		"entry_count": view_models.size(),
		"revision": int(snapshot.revision) if snapshot != null else -1,
	})
	for view_model in view_models:
		var label_text := String(view_model.get("summary_text", view_model.get("room_display_name", "")))
		public_room_list.add_item(label_text)
		public_room_list.set_item_metadata(public_room_list.item_count - 1, String(view_model.get("room_id", "")))
	_set_directory_status("Loaded %d public room(s)." % public_room_list.item_count)


func _log_phase15(event_name: String, payload: Dictionary) -> void:
	LogFrontScript.debug("%s[lobby_scene] %s %s" % [PHASE15_LOG_PREFIX, event_name, JSON.stringify(payload)], "", 0, "front.lobby.scene")


func _log_online_lobby(event_name: String, payload: Dictionary) -> void:
	LogFrontScript.debug("%s[lobby_scene] %s %s" % [ONLINE_LOG_PREFIX, event_name, JSON.stringify(payload)], "", 0, "front.lobby.online")


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
		"game_service_host": game_service_host_input.text.strip_edges() if game_service_host_input != null else "",
		"game_service_port": int(game_service_port_input.text.to_int()) if game_service_port_input != null else 0,
		"queue_assignment_consuming": _queue_assignment_consuming,
	}
