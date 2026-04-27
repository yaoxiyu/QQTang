extends "res://scenes/front/room/room_formal_slot_presenter.gd"

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
	if not _can_edit_formal_room_properties():
		_set_room_feedback("只有房主可以选择模式")
		return
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
	if not _can_edit_formal_room_properties():
		_set_room_feedback("只有房主可以修改房间属性")
		return
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
	if not _can_edit_formal_room_properties():
		_set_room_feedback("只有房主可以选择地图")
		return
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
	if not _can_edit_formal_room_properties():
		_set_room_feedback("只有房主可以选择地图")
		return
	if _last_room_snapshot != null and _last_room_snapshot.members.size() > max_players:
		_set_room_feedback("当前人数超过地图人数要求")
		return
	var binding := MapSelectionCatalogScript.get_map_binding(map_id)
	if binding.is_empty():
		_set_room_feedback("地图配置无效")
		return
	_formal_closed_slots.clear()
	_apply_formal_slot_capacity(max_players)
	_formal_custom_open_slots = _count_formal_open_custom_slots()
	var mode_id := String(binding.get("bound_mode_id", ""))
	var rule_set_id := String(binding.get("bound_rule_set_id", ""))
	if _room_use_case == null:
		_set_room_feedback("房间服务未连接")
		return
	var result: Dictionary = _room_use_case.update_selection(map_id, rule_set_id, mode_id)
	if not bool(result.get("ok", false)):
		_set_room_feedback(String(result.get("user_message", "地图切换失败")))
		return
	var map_display_name := _resolve_formal_map_display_name(map_id)
	if _formal_room_map_label != null:
		_formal_room_map_label.text = "地图: %s" % map_display_name
	if _formal_map_preview_label != null:
		_formal_map_preview_label.text = map_display_name
	_last_room_view_model["selected_map_id"] = map_id
	_last_room_view_model["max_player_count"] = max_players
	_formal_display_mode = String(binding.get("mode_name", _formal_display_mode))
	if _formal_room_mode_label != null and not _formal_display_mode.is_empty():
		_formal_room_mode_label.text = "模式: %s" % _formal_display_mode
	_set_room_feedback("地图设置已提交")
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


