extends "res://scenes/front/room/room_formal_theme_applier.gd"

func _apply_formal_room_layout() -> void:
	_ensure_room_background()
	_build_reference_room_layout()
	if room_scroll != null:
		room_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		room_scroll.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
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
	for button in [back_to_lobby_button, leave_room_button, enter_queue_button, cancel_queue_button, add_opponent_button, copy_invite_code_button]:
		_apply_room_button_style(button)
	_apply_room_action_button_style(ready_button, "ready")
	_apply_room_action_button_style(start_button, "start")
	for input in [room_id_value_label, player_name_input, invite_code_value_label]:
		_apply_room_input_style(input)
	for selector in [team_selector, character_selector, bubble_selector, map_selector, game_mode_selector, match_format_selector]:
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
	slots_panel.add_theme_stylebox_override("panel", _make_room_style(Color(0.08, 0.10, 0.12, 0.30), Color(0.18, 0.22, 0.28, 0.22), 6))
	slots_panel.set_meta("ui_asset_id", "ui.room.panel.player_slots")
	left_panel.add_child(slots_panel)
	_formal_slot_grid = GridContainer.new()
	_formal_slot_grid.columns = 4
	_formal_slot_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_formal_slot_grid.custom_minimum_size = Vector2(0, 292)
	_formal_slot_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_formal_slot_grid.add_theme_constant_override("h_separation", 12)
	_formal_slot_grid.add_theme_constant_override("v_separation", 12)
	slots_panel.add_child(_formal_slot_grid)

	var chat_panel := PanelContainer.new()
	chat_panel.custom_minimum_size = Vector2(0, 118)
	chat_panel.add_theme_stylebox_override("panel", _make_room_style(Color(0.08, 0.11, 0.13, 0.35), Color(0.12, 0.58, 0.82, 0.65), 8))
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

	var property_outer := HBoxContainer.new()
	property_outer.add_theme_constant_override("separation", 8)
	right_panel.add_child(property_outer)
	var property_vbox := VBoxContainer.new()
	property_vbox.add_theme_constant_override("separation", 5)
	property_outer.add_child(property_vbox)
	_formal_choose_mode_button = _create_formal_room_button("选择模式", _on_formal_choose_mode_pressed)
	_apply_room_texture_button_style(_formal_choose_mode_button, ROOM_ASSETS.btn_sel_mode_normal_path, ROOM_ASSETS.btn_sel_mode_hover_path, ROOM_ASSETS.btn_sel_mode_pressed_path, ROOM_ASSETS.btn_sel_mode_disabled_path)
	property_vbox.add_child(_formal_choose_mode_button)
	_formal_room_property_button = _create_formal_room_button("房间属性", _on_formal_room_property_pressed)
	_apply_room_texture_button_style(_formal_room_property_button, ROOM_ASSETS.btn_property_normal_path, ROOM_ASSETS.btn_property_hover_path, ROOM_ASSETS.btn_property_pressed_path, ROOM_ASSETS.btn_property_disabled_path)
	property_vbox.add_child(_formal_room_property_button)
	_formal_choose_map_button = _create_formal_room_button("选择地图", _on_formal_choose_map_pressed)
	_apply_room_texture_button_style(_formal_choose_map_button, ROOM_ASSETS.btn_sel_map_normal_path, ROOM_ASSETS.btn_sel_map_hover_path, ROOM_ASSETS.btn_sel_map_pressed_path, ROOM_ASSETS.btn_sel_map_disabled_path)
	property_vbox.add_child(_formal_choose_map_button)
	var map_preview := TextureRect.new()
	map_preview.name = "MapPreview"
	map_preview.custom_minimum_size = Vector2(95, 95)
	map_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	map_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	property_outer.add_child(map_preview)

	var loadout_panel := PanelContainer.new()
	loadout_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	loadout_panel.add_theme_stylebox_override("panel", _make_room_style(Color(0.08, 0.10, 0.12, 0.30), Color(0.18, 0.22, 0.28, 0.22), 6))
	loadout_panel.set_meta("ui_asset_id", "ui.room.panel.loadout_preview")
	right_panel.add_child(loadout_panel)
	var loadout_vbox := VBoxContainer.new()
	loadout_vbox.add_theme_constant_override("separation", 5)
	loadout_panel.add_child(loadout_vbox)
	var character_title := Label.new()
	character_title.text = "角色选择"
	loadout_vbox.add_child(character_title)
	_formal_character_tab_row = HBoxContainer.new()
	_formal_character_tab_row.add_theme_constant_override("separation", 4)
	loadout_vbox.add_child(_formal_character_tab_row)
	_formal_character_normal_tab_button = _create_formal_room_button("普通角色", Callable(self, "_select_formal_character_category").bind("normal"))
	_formal_character_normal_tab_button.toggle_mode = true
	_formal_character_normal_tab_button.custom_minimum_size = Vector2(92, 28)
	_apply_room_small_button_style(_formal_character_normal_tab_button)
	_formal_character_tab_row.add_child(_formal_character_normal_tab_button)
	_formal_character_vip_tab_button = _create_formal_room_button("VIP角色", Callable(self, "_select_formal_character_category").bind("vip"))
	_formal_character_vip_tab_button.toggle_mode = true
	_formal_character_vip_tab_button.custom_minimum_size = Vector2(92, 28)
	_apply_room_small_button_style(_formal_character_vip_tab_button)
	_formal_character_tab_row.add_child(_formal_character_vip_tab_button)
	_formal_character_grid = GridContainer.new()
	_formal_character_grid.columns = 4
	_formal_character_grid.custom_minimum_size = Vector2(0, 160)
	_formal_character_grid.add_theme_constant_override("h_separation", 6)
	_formal_character_grid.add_theme_constant_override("v_separation", 6)
	var character_row := HBoxContainer.new()
	character_row.add_theme_constant_override("separation", 4)
	loadout_vbox.add_child(character_row)
	_formal_character_prev_button = _create_role_nav_button(true, Callable(self, "_change_formal_character_page").bind(-1))
	character_row.add_child(_formal_character_prev_button)
	character_row.add_child(_formal_character_grid)
	_formal_character_next_button = _create_role_nav_button(false, Callable(self, "_change_formal_character_page").bind(1))
	character_row.add_child(_formal_character_next_button)
	_formal_character_page_label = Label.new()
	_formal_character_page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loadout_vbox.add_child(_formal_character_page_label)
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

