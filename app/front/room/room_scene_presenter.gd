class_name RoomScenePresenter
extends RefCounted


func present(view_model: Dictionary, scene_controller: Node) -> void:
	if scene_controller == null:
		return
	_set_text(scene_controller, "title_label", String(view_model.get("title_text", "")))
	_set_text(scene_controller, "room_meta_label", _build_room_meta_text(view_model))
	_set_text(scene_controller, "room_kind_label", "Room Kind: %s" % String(view_model.get("room_kind_text", "")))
	_set_text(scene_controller, "room_display_name_label", String(view_model.get("room_display_name", "")))
	_set_text(scene_controller, "room_id_value_label", "Room ID: %s" % String(view_model.get("room_id_text", "")))
	_set_text(scene_controller, "connection_status_label", "Connection: %s" % String(view_model.get("connection_status_text", "")))
	_set_text(scene_controller, "owner_label", "Owner: %s" % String(view_model.get("owner_text", "")))
	_set_text(scene_controller, "blocker_label", String(view_model.get("blocker_text", "")))
	_set_text(scene_controller, "lifecycle_status_label", String(view_model.get("lifecycle_status_text", "")))
	_set_text(scene_controller, "pending_action_status_label", String(view_model.get("pending_action_status_text", "")))
	_set_text(scene_controller, "reconnect_window_label", String(view_model.get("reconnect_window_text", "")))
	_set_text(scene_controller, "active_match_resume_label", String(view_model.get("active_match_resume_text", "")))
	_set_text(scene_controller, "eligible_map_pool_hint_label", String(view_model.get("eligible_map_pool_hint_text", "")))
	_set_text(scene_controller, "invite_code_value_label", String(view_model.get("invite_code_text", "")))
	_set_text(scene_controller, "queue_status_label", String(view_model.get("queue_status_text", "")))
	_set_text(scene_controller, "queue_error_label", String(view_model.get("queue_error_text", "")))

	_set_visible(scene_controller, "room_display_name_label", not String(view_model.get("room_display_name", "")).is_empty())
	_set_visible(scene_controller, "room_id_value_label", bool(view_model.get("show_room_id", true)))
	_set_visible(scene_controller, "connection_status_label", bool(view_model.get("show_connection_status", true)))
	_set_visible(scene_controller, "add_opponent_button", bool(view_model.get("show_add_opponent", false)))
	_set_visible(scene_controller, "match_format_selector", bool(view_model.get("show_match_format_selector", false)))
	_set_visible(scene_controller, "match_mode_multi_select", bool(view_model.get("show_match_mode_multi_select", false)))
	_set_visible(scene_controller, "team_selector", bool(view_model.get("show_team_selector", true)))
	_set_visible(scene_controller, "enter_queue_button", bool(view_model.get("show_queue_buttons", false)))
	_set_visible(scene_controller, "cancel_queue_button", bool(view_model.get("show_queue_buttons", false)))
	_set_disabled(scene_controller, "map_selector", not bool(view_model.get("can_edit_selection", false)))
	_set_disabled(scene_controller, "game_mode_selector", not bool(view_model.get("can_edit_selection", false)))
	_set_disabled(scene_controller, "team_selector", not bool(view_model.get("can_edit_team", true)))
	_set_disabled(scene_controller, "match_format_selector", not bool(view_model.get("can_edit_match_room_config", false)))
	_set_disabled(scene_controller, "match_mode_multi_select", not bool(view_model.get("can_edit_match_room_config", false)))
	_set_disabled(scene_controller, "ready_button", not bool(view_model.get("can_ready", false)))
	_set_disabled(scene_controller, "start_button", not bool(view_model.get("can_start", false)))
	_set_disabled(scene_controller, "enter_queue_button", not bool(view_model.get("can_enter_queue", false)))
	_set_disabled(scene_controller, "cancel_queue_button", not bool(view_model.get("can_cancel_queue", false)))
	_set_text(scene_controller, "rule_value_label", String(view_model.get("selected_rule_display_name", view_model.get("selected_rule_set_id", ""))))
	_set_visible(scene_controller, "rule_value_label", true)
	_set_visible(scene_controller, "ready_button", bool(view_model.get("is_custom_room", false)) or bool(view_model.get("is_match_room", false)))
	_set_visible(scene_controller, "start_button", bool(view_model.get("is_custom_room", false)))
	_set_button_text(
		scene_controller,
		"ready_button",
		"Cancel Ready" if bool(view_model.get("local_member_ready", false)) else "Ready"
	)
	_set_button_text(scene_controller, "start_button", "Start Match")
	_set_button_text(scene_controller, "enter_queue_button", "开始匹配")
	_set_button_text(scene_controller, "cancel_queue_button", "取消匹配")
	_set_button_text(scene_controller, "add_opponent_button", "Add Opponent")
	_render_member_list(scene_controller, view_model.get("members", []))


func _build_room_meta_text(view_model: Dictionary) -> String:
	return "%s | %s" % [
		String(view_model.get("room_kind_text", "")),
		String(view_model.get("topology_text", "")),
	]


func _render_member_list(scene_controller: Node, members_data) -> void:
	if not scene_controller.get("member_list"):
		return
	var member_list = scene_controller.get("member_list")
	if member_list == null:
		return
	for child in member_list.get_children():
		child.queue_free()
	for entry in members_data:
		if not (entry is Dictionary):
			continue
		var label := Label.new()
		var owner_suffix := " [Host]" if bool(entry.get("is_owner", false)) else ""
		var local_suffix := " [You]" if bool(entry.get("is_local_player", false)) else ""
		var team_suffix := " | Team %d" % int(entry.get("team_id", 1))
		var ready_suffix := " Ready" if bool(entry.get("ready", false)) else " Not Ready"
		var connection_state := String(entry.get("connection_state", "connected"))
		var connection_suffix := "" if connection_state.is_empty() or connection_state == "connected" else " [%s]" % connection_state
		label.text = "%s%s%s%s%s%s" % [
			String(entry.get("player_name", "")),
			owner_suffix,
			local_suffix,
			team_suffix,
			ready_suffix,
			connection_suffix,
		]
		member_list.add_child(label)


func _set_text(scene_controller: Node, property_name: String, text: String) -> void:
	var node = scene_controller.get(property_name)
	if node == null:
		return
	if node is Label:
		node.text = text
	elif node is LineEdit:
		node.text = text


func _set_button_text(scene_controller: Node, property_name: String, text: String) -> void:
	var node = scene_controller.get(property_name)
	if node is Button:
		node.text = text


func _set_visible(scene_controller: Node, property_name: String, visible: bool) -> void:
	var node = scene_controller.get(property_name)
	if node is CanvasItem:
		node.visible = visible


func _set_disabled(scene_controller: Node, property_name: String, disabled: bool) -> void:
	var node = scene_controller.get(property_name)
	if node is LineEdit:
		node.editable = not disabled
		return
	if node is ItemList:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE if disabled else Control.MOUSE_FILTER_STOP
		return
	if node is BaseButton:
		node.disabled = disabled
		return
	if node is OptionButton:
		node.disabled = disabled
