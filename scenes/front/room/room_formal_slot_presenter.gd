extends "res://scenes/front/room/room_formal_loadout_presenter.gd"

var _formal_slot_grid_signature: String = ""


func _refresh_formal_room_slots(snapshot: RoomSnapshot, view_model: Dictionary) -> void:
	if _formal_slot_grid == null or snapshot == null:
		return
	var open_slot_count := _resolve_formal_open_slot_count(snapshot, view_model)
	var max_player_count := int(view_model.get("max_player_count", snapshot.max_players))
	if max_player_count <= 0:
		max_player_count = FORMAL_ROOM_SLOT_COUNT
	var signature := _build_formal_slot_grid_signature(snapshot, view_model, open_slot_count, max_player_count)
	if signature == _formal_slot_grid_signature and _formal_slot_grid.get_child_count() > 0:
		return
	_formal_slot_grid_signature = signature
	for child in _formal_slot_grid.get_children():
		child.queue_free()
	for slot_index in range(FORMAL_ROOM_SLOT_COUNT):
		var member := _find_member_for_slot(snapshot, slot_index)
		var is_open := slot_index < open_slot_count
		if bool(view_model.get("is_custom_room", false)):
			is_open = _is_formal_custom_slot_open(slot_index, max_player_count)
		_formal_slot_grid.add_child(_create_formal_slot_card(slot_index, member, is_open, view_model))


func _create_formal_slot_card(slot_index: int, member: RoomMemberState, is_open: bool, view_model: Dictionary) -> Control:
	var button := Button.new()
	button.custom_minimum_size = Vector2(132, 137)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	var is_top_slot := slot_index < 4
	var normal_tex := _make_texture_style(ROOM_ASSETS.slot_player_up_normal_path if is_top_slot else ROOM_ASSETS.slot_player_down_normal_path)
	var hover_tex := _make_texture_style(ROOM_ASSETS.slot_player_up_hover_path if is_top_slot else ROOM_ASSETS.slot_player_down_hover_path)
	button.add_theme_stylebox_override("normal", normal_tex)
	button.add_theme_stylebox_override("hover", hover_tex)
	button.add_theme_stylebox_override("pressed", normal_tex)
	button.add_theme_stylebox_override("disabled", normal_tex)
	if member != null:
		button.text = ""
		button.tooltip_text = member.player_name
		button.set_meta("ui_asset_id", "ui.room.slot.occupied")
		button.pressed.connect(Callable(self, "_show_formal_member_profile").bind(_member_to_profile_payload(member)))
		_add_formal_character_preview(button, member.character_id, 126.0, member.team_id)
		_add_formal_slot_team_overlay(button, member.team_id, member.player_name, is_top_slot)
	elif is_open:
		button.text = ""
		button.tooltip_text = "空位"
		button.disabled = not _can_toggle_formal_custom_slot(view_model)
		button.set_meta("ui_asset_id", "ui.room.slot.empty")
		button.pressed.connect(Callable(self, "_toggle_formal_slot").bind(slot_index))
	else:
		button.text = ""
		button.tooltip_text = "已关闭"
		button.disabled = not _can_toggle_formal_custom_slot(view_model)
		button.set_meta("ui_asset_id", "ui.room.slot.closed")
		button.pressed.connect(Callable(self, "_toggle_formal_slot").bind(slot_index))
		var closed_overlay := TextureRect.new()
		closed_overlay.name = "SlotClosedOverlay"
		closed_overlay.texture = load(ROOM_ASSETS.slot_closed_overlay_path)
		closed_overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		closed_overlay.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		closed_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
		closed_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(closed_overlay)
	return button


func _refresh_formal_room_actions(snapshot: RoomSnapshot, view_model: Dictionary) -> void:
	if snapshot == null:
		return
	var is_host := _is_local_host(snapshot)
	var is_match_room := bool(view_model.get("is_match_room", false))
	if ready_button != null:
		var is_ready := bool(view_model.get("local_member_ready", false))
		ready_button.text = ""
		_apply_room_action_button_style(ready_button, "unready" if is_ready else "ready")
		ready_button.visible = not is_host
		ready_button.disabled = not bool(view_model.get("can_ready", false))
	if start_button != null:
		start_button.text = ""
		_apply_room_action_button_style(start_button, "start")
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
				var button := child as Button
				var is_selected := String(button.get_meta("character_id", "")) == selected_character_id
				button.button_pressed = is_selected
				var texture_rect := _find_character_button_texture_rect(button)
				if texture_rect != null:
					var icon_path := String(button.get_meta("icon_selected_path", "")) if is_selected else String(button.get_meta("icon_path", ""))
					if not icon_path.is_empty():
						var icon_texture := _load_formal_character_icon(icon_path)
						if icon_texture != null:
							texture_rect.texture = icon_texture
	if _formal_team_row != null:
		for child in _formal_team_row.get_children():
			if child is Button:
				(child as Button).button_pressed = int(child.get_meta("team_id", 0)) == selected_team_id


func _add_formal_slot_team_overlay(button: Button, team_id: int, player_name: String, is_top: bool) -> void:
	var strip_path := ROOM_ASSETS.get("team_color_strip_%d_path" % clampi(team_id, 1, 8)) as String
	var strip := TextureRect.new()
	strip.name = "TeamColorStrip"
	strip.texture = load(strip_path)
	strip.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	strip.stretch_mode = TextureRect.STRETCH_KEEP
	strip.custom_minimum_size = Vector2(117, 20)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Anchor at top-center or bottom-center
	strip.anchor_left = 0.5
	strip.anchor_right = 0.5
	if is_top:
		strip.anchor_top = 0.0
		strip.anchor_bottom = 0.0
		strip.offset_left = -58
		strip.offset_top = 2
		strip.offset_right = 59
		strip.offset_bottom = 22
	else:
		strip.anchor_top = 1.0
		strip.anchor_bottom = 1.0
		strip.offset_left = -58
		strip.offset_top = -22
		strip.offset_right = 59
		strip.offset_bottom = -2
	button.add_child(strip)
	var name_label := Label.new()
	name_label.name = "PlayerName"
	name_label.text = player_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 10)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	strip.add_child(name_label)

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


func _build_formal_slot_grid_signature(snapshot: RoomSnapshot, view_model: Dictionary, open_slot_count: int, max_player_count: int) -> String:
	var parts := PackedStringArray()
	parts.append(str(open_slot_count))
	parts.append(str(max_player_count))
	parts.append(str(bool(view_model.get("is_custom_room", false))))
	var open_slots := snapshot.open_slot_indices.duplicate()
	open_slots.sort()
	for slot_index in open_slots:
		parts.append("open:%d" % int(slot_index))
	for member in snapshot.sorted_members():
		if member == null:
			continue
		parts.append("%d:%d:%s:%s:%d:%s:%s" % [
			int(member.slot_index),
			int(member.peer_id),
			String(member.player_name),
			String(member.character_id),
			int(member.team_id),
			
			String(member.connection_state),
		])
	return "|".join(parts)


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
