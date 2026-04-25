class_name RoomSceneViewBinder
extends RefCounted

const CharacterCatalogScript = preload("res://content/characters/catalog/character_catalog.gd")
const CharacterSkinCatalogScript = preload("res://content/character_skins/catalog/character_skin_catalog.gd")
const MapSelectionCatalogScript = preload("res://content/maps/catalog/map_selection_catalog.gd")


func apply_room_kind_visibility(scene_controller: Node, view_model: Dictionary) -> void:
	var room_kind := String(view_model.get("room_kind", ""))
	var is_custom_room := bool(view_model.get("is_custom_room", room_kind == "practice" or room_kind == "custom_room" or room_kind == "private_room" or room_kind == "public_room"))
	var is_match_room := bool(view_model.get("is_match_room", room_kind == "casual_match_room" or room_kind == "ranked_match_room"))
	var is_assigned_room := bool(view_model.get("is_assigned_room", room_kind == "matchmade_room"))
	_set_node_visible(scene_controller, "RoomRoot/RoomScroll/MainLayout/RoomSelectionCard/RoomSelectionVBox/MapRow", is_custom_room or is_assigned_room)
	_set_node_visible(scene_controller, "RoomRoot/RoomScroll/MainLayout/RoomSelectionCard/RoomSelectionVBox/RuleRow", is_custom_room or is_assigned_room)
	_set_node_visible(scene_controller, "RoomRoot/RoomScroll/MainLayout/RoomSelectionCard/RoomSelectionVBox/ModeRow", is_custom_room or is_assigned_room)
	_set_node_visible(scene_controller, "RoomRoot/RoomScroll/MainLayout/LocalLoadoutCard/LocalLoadoutVBox/TeamRow", is_custom_room)
	_set_node_visible(scene_controller, "RoomRoot/RoomScroll/MainLayout/RoomSelectionCard/RoomSelectionVBox/MatchFormatRow", is_match_room)
	_set_node_visible(scene_controller, "RoomRoot/RoomScroll/MainLayout/RoomSelectionCard/RoomSelectionVBox/MatchModeRow", is_match_room)
	_set_node_visible(scene_controller, "RoomRoot/RoomScroll/MainLayout/RoomSelectionCard/RoomSelectionVBox/InviteRow", is_match_room)
	_set_node_visible(scene_controller, "RoomRoot/RoomScroll/MainLayout/RoomSelectionCard/RoomSelectionVBox/QueueStatusRow", is_match_room)
	_set_visible_by_name(scene_controller, "start_button", is_custom_room)
	_set_visible_by_name(scene_controller, "enter_queue_button", is_match_room)
	_set_visible_by_name(scene_controller, "cancel_queue_button", is_match_room)
	_set_visible_by_name(scene_controller, "ready_button", is_custom_room or is_match_room)


func refresh_match_room_controls(scene_controller: Node, snapshot: RoomSnapshot, view_model: Dictionary, selected_mode_ids: Array[String]) -> void:
	if snapshot == null:
		return
	_set_text_by_name(scene_controller, "invite_code_value_label", String(view_model.get("invite_code_text", snapshot.room_id)))
	_set_text_by_name(scene_controller, "queue_status_label", String(view_model.get("queue_status_text", snapshot.room_queue_status_text)))
	_set_text_by_name(scene_controller, "queue_error_label", String(view_model.get("queue_error_text", snapshot.room_queue_error_message)))
	_set_button_disabled_by_name(scene_controller, "enter_queue_button", not bool(view_model.get("can_enter_queue", false)))
	_set_button_disabled_by_name(scene_controller, "cancel_queue_button", not bool(view_model.get("can_cancel_queue", false)))
	update_eligible_map_pool_hint(scene_controller, snapshot.queue_type, snapshot.match_format_id, selected_mode_ids)


func update_preview(
	scene_controller: Node,
	snapshot: RoomSnapshot,
	app_runtime: Node,
	local_member: RoomMemberState,
	selected_team_id: int
) -> void:
	if snapshot == null:
		return
	_set_text_by_name(scene_controller, "map_preview_label", "Map: %s" % snapshot.selected_map_id)
	_set_text_by_name(scene_controller, "rule_preview_label", "Rule: %s" % snapshot.rule_set_id)
	_set_text_by_name(scene_controller, "mode_preview_label", "Mode: %s" % snapshot.mode_id)
	if local_member != null:
		_set_text_by_name(scene_controller, "team_preview_label", "Team: %d" % local_member.team_id)
		_set_text_by_name(scene_controller, "character_preview_label", "Character: %s" % local_member.character_id)
		_set_text_by_name(scene_controller, "character_skin_preview_label", "Character Skin: %s" % local_member.character_skin_id)
		_set_text_by_name(scene_controller, "bubble_preview_label", "Bubble: %s" % local_member.bubble_style_id)
		_set_text_by_name(scene_controller, "bubble_skin_preview_label", "Bubble Skin: %s" % local_member.bubble_skin_id)
		_configure_preview(scene_controller, local_member.character_id, local_member.character_skin_id)
		return
	if app_runtime == null or app_runtime.player_profile_state == null:
		return
	var profile = app_runtime.player_profile_state
	_set_text_by_name(scene_controller, "team_preview_label", "Team: %d" % selected_team_id)
	_set_text_by_name(scene_controller, "character_preview_label", "Character: %s" % String(profile.default_character_id))
	_set_text_by_name(scene_controller, "character_skin_preview_label", "Character Skin: %s" % String(profile.default_character_skin_id))
	_set_text_by_name(scene_controller, "bubble_preview_label", "Bubble: %s" % String(profile.default_bubble_style_id))
	_set_text_by_name(scene_controller, "bubble_skin_preview_label", "Bubble Skin: %s" % String(profile.default_bubble_skin_id))
	if String(profile.get("title_id")).strip_edges() != "":
		_set_text_by_name(scene_controller, "mode_preview_label", "Mode: %s | Title: %s" % [snapshot.mode_id, String(profile.get("title_id"))])
	if String(profile.get("avatar_id")).strip_edges() != "":
		_set_text_by_name(scene_controller, "team_preview_label", "Team: %d | Avatar: %s" % [selected_team_id, String(profile.get("avatar_id"))])
	_configure_preview(
		scene_controller,
		_resolve_preview_character_id(String(profile.default_character_id)),
		_resolve_preview_character_skin_id(String(profile.default_character_skin_id))
	)


func update_auth_binding_summary(scene_controller: Node, snapshot: RoomSnapshot, app_runtime: Node, local_member: RoomMemberState) -> void:
	var auth_binding_label = _get_property(scene_controller, "auth_binding_label")
	if auth_binding_label == null:
		return
	var account_id := ""
	var profile_id := ""
	var member_id := ""
	var device_session_id := ""
	if app_runtime != null and app_runtime.current_room_entry_context != null:
		account_id = String(app_runtime.current_room_entry_context.account_id)
		profile_id = String(app_runtime.current_room_entry_context.profile_id)
		member_id = String(app_runtime.current_room_entry_context.reconnect_member_id)
	if app_runtime != null and app_runtime.auth_session_state != null:
		if account_id.is_empty():
			account_id = String(app_runtime.auth_session_state.account_id)
		if profile_id.is_empty():
			profile_id = String(app_runtime.auth_session_state.profile_id)
		device_session_id = String(app_runtime.auth_session_state.device_session_id)
	if member_id.is_empty() and app_runtime != null and app_runtime.front_settings_state != null:
		member_id = String(app_runtime.front_settings_state.reconnect_member_id)
	if member_id.is_empty() and local_member != null:
		member_id = "peer_%d" % int(local_member.peer_id)
	var text := "Identity Binding:\naccount=%s\nprofile=%s\nmember=%s\nsession=%s" % [
		account_id if not account_id.is_empty() else "-",
		profile_id if not profile_id.is_empty() else "-",
		member_id if not member_id.is_empty() else "-",
		device_session_id if not device_session_id.is_empty() else "-",
	]
	if auth_binding_label is Label:
		auth_binding_label.text = text


func update_debug_text(scene_controller: Node, snapshot: RoomSnapshot, view_model: Dictionary) -> void:
	var debug_label = _get_property(scene_controller, "debug_label")
	if not (debug_label is Label) or snapshot == null:
		return
	var lines := PackedStringArray()
	lines.append("Room: %s" % snapshot.room_id)
	lines.append("Kind: %s" % String(view_model.get("room_kind_text", "")))
	lines.append("Topology: %s" % String(view_model.get("topology_text", "")))
	lines.append("Map: %s" % snapshot.selected_map_id)
	lines.append("Rule: %s" % snapshot.rule_set_id)
	lines.append("Mode: %s" % snapshot.mode_id)
	lines.append("Owner: %s" % String(view_model.get("owner_text", "")))
	lines.append("OwnerPeer: %d LocalPeer: %d" % [int(snapshot.owner_peer_id), int(scene_controller._app_runtime.local_peer_id) if scene_controller._app_runtime != null else 0])
	lines.append("Members: %d ReadyAll: %s" % [snapshot.members.size(), str(bool(snapshot.all_ready))])
	lines.append("CanStart: %s CanQueue: %s" % [str(bool(view_model.get("can_start", false))), str(bool(view_model.get("can_enter_queue", false)))])
	lines.append("QueueType: %s Format: %s Modes: %s" % [String(snapshot.queue_type), String(snapshot.match_format_id), JSON.stringify(snapshot.selected_match_mode_ids)])
	lines.append("Blocker: %s" % String(view_model.get("blocker_text", "")))
	debug_label.text = "\n".join(lines)


func set_room_feedback(scene_controller: Node, message: String) -> void:
	_set_text_by_name(scene_controller, "blocker_label", message)
	_set_text_by_name(scene_controller, "debug_label", message)


func update_eligible_map_pool_hint(scene_controller: Node, queue_type: String, match_format_id: String, selected_mode_ids: Array[String]) -> void:
	var hint_label = _get_property(scene_controller, "eligible_map_pool_hint_label")
	if not (hint_label is Label):
		return
	var count := MapSelectionCatalogScript.get_match_room_eligible_map_count(queue_type, match_format_id, selected_mode_ids)
	if count <= 0:
		hint_label.text = "当前选择没有合法地图"
	else:
		hint_label.text = "当前模式池可匹配 %d 张地图" % count


func _set_node_visible(scene_controller: Node, path: String, visible: bool) -> void:
	var node := scene_controller.get_node_or_null(path)
	if node is CanvasItem:
		(node as CanvasItem).visible = visible


func _set_visible_by_name(scene_controller: Node, property_name: String, visible: bool) -> void:
	var node = _get_property(scene_controller, property_name)
	if node is CanvasItem:
		node.visible = visible


func _set_button_disabled_by_name(scene_controller: Node, property_name: String, disabled: bool) -> void:
	var node = _get_property(scene_controller, property_name)
	if node is BaseButton:
		node.disabled = disabled


func _set_text_by_name(scene_controller: Node, property_name: String, value: String) -> void:
	var node = _get_property(scene_controller, property_name)
	if node is Label:
		node.text = value
	elif node is LineEdit:
		node.text = value


func _configure_preview(scene_controller: Node, character_id: String, character_skin_id: String) -> void:
	var viewport = _get_property(scene_controller, "character_preview_viewport")
	if viewport != null and viewport.has_method("configure_preview"):
		viewport.configure_preview(character_id, character_skin_id)


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


func _get_property(scene_controller: Node, property_name: String):
	if scene_controller == null:
		return null
	return scene_controller.get(property_name)
