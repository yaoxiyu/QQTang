extends "res://scenes/front/room/room_formal_theme_applier.gd"

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


