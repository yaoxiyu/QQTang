extends "res://scenes/front/room/room_formal_layout_builder.gd"

const FORMAL_RANDOM_CHARACTER_ID := "12301"

var _formal_character_grid_signature: String = ""
var _formal_character_entries_cache_signature: String = ""
var _formal_character_entries_cache: Array[Dictionary] = []
var _formal_character_icon_cache: Dictionary = {}


func _build_formal_character_buttons() -> void:
	if _formal_character_grid == null:
		return
	_refresh_formal_character_tabs()
	var entries := _get_formal_character_entries()
	var max_page := _get_formal_character_max_page(entries.size())
	_formal_character_page = clampi(_formal_character_page, 0, max_page)
	var signature := _build_formal_character_grid_signature(entries)
	if signature == _formal_character_grid_signature and _formal_character_grid.get_child_count() > 0:
		return
	_formal_character_grid_signature = signature
	for child in _formal_character_grid.get_children():
		child.queue_free()
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
		_apply_room_square_button_style(button, Color(0.33, 0.72, 0.86, 0.95))
		_add_formal_character_icon(button, entry, character_id == _selected_formal_character_id())
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


func _add_formal_character_icon(parent: Control, entry: Dictionary, selected: bool) -> void:
	var character_id := String(entry.get("id", ""))
	var icon_path := String(entry.get("selection_icon_selected_path", "")) if selected else String(entry.get("selection_icon_path", ""))
	if icon_path.is_empty():
		icon_path = String(entry.get("selection_icon_path", ""))
	var texture := _load_formal_character_icon(icon_path)
	if texture == null:
		if parent is Button:
			(parent as Button).text = _formal_character_button_label(character_id)
		return
	var rect := TextureRect.new()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.offset_left = 3.0
	rect.offset_top = 3.0
	rect.offset_right = -3.0
	rect.offset_bottom = -3.0
	parent.add_child(rect)


func _load_formal_character_icon(icon_path: String) -> Texture2D:
	var normalized := icon_path.strip_edges()
	if normalized.is_empty():
		return null
	if _formal_character_icon_cache.has(normalized):
		return _formal_character_icon_cache[normalized]
	if not FileAccess.file_exists(normalized):
		_formal_character_icon_cache[normalized] = null
		return null
	var image := Image.load_from_file(ProjectSettings.globalize_path(normalized))
	if image == null or image.is_empty():
		_formal_character_icon_cache[normalized] = null
		return null
	var texture := ImageTexture.create_from_image(image)
	_formal_character_icon_cache[normalized] = texture
	return texture


func _add_formal_character_preview(parent: Control, character_id: String, character_skin_id: String, size: float, team_id: int = 0) -> void:
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
		preview.call_deferred("configure_preview", character_id, character_skin_id, team_id)


func _color_for_character_id(character_id: String) -> Color:
	var hash_value: int = abs(character_id.hash())
	var hue := float(hash_value % 360) / 360.0
	return Color.from_hsv(hue, 0.48, 0.86, 1.0)


func _get_formal_character_max_page(entry_count: int) -> int:
	if entry_count <= 0:
		return 0
	return int(ceil(float(entry_count) / 8.0)) - 1


func _select_formal_character_category(category: String) -> void:
	var normalized := category.strip_edges().to_lower()
	if normalized != "vip":
		normalized = "normal"
	if _formal_character_category == normalized:
		return
	_formal_character_category = normalized
	_formal_character_page = 0
	_formal_character_grid_signature = ""
	_formal_character_entries_cache_signature = ""
	_build_formal_character_buttons()
	_refresh_formal_loadout_selection(_last_room_view_model)


func _refresh_formal_character_tabs() -> void:
	if _formal_character_normal_tab_button != null:
		_formal_character_normal_tab_button.button_pressed = _formal_character_category == "normal"
	if _formal_character_vip_tab_button != null:
		_formal_character_vip_tab_button.button_pressed = _formal_character_category == "vip"


func _get_formal_character_entries() -> Array[Dictionary]:
	var cache_signature := _formal_character_category
	if cache_signature == _formal_character_entries_cache_signature:
		return _formal_character_entries_cache.duplicate(true)
	var entries: Array[Dictionary] = []
	for entry in CharacterCatalogScript.get_character_selector_entries():
		var character_id := String(entry.get("id", "")).strip_edges()
		if character_id.is_empty():
			continue
		var character_type := int(entry.get("type", 0))
		if _formal_character_category == "normal":
			if character_id == FORMAL_RANDOM_CHARACTER_ID:
				continue
			if character_type != CharacterCatalogScript.TYPE_DEFAULT_SELECTABLE:
				continue
		elif character_type != CharacterCatalogScript.TYPE_VIP_SELECTABLE:
			continue
		entries.append({
			"id": character_id,
			"display_name": String(entry.get("display_name", character_id)),
			"selection_order": int(entry.get("selection_order", 999999)),
			"type": int(entry.get("type", 0)),
			"selection_icon_path": String(entry.get("selection_icon_path", "")),
			"selection_icon_selected_path": String(entry.get("selection_icon_selected_path", "")),
		})
	if _formal_character_category == "normal":
		var random_entry := CharacterCatalogScript.get_character_entry(FORMAL_RANDOM_CHARACTER_ID)
		if not random_entry.is_empty():
			entries.push_front({
				"id": FORMAL_RANDOM_CHARACTER_ID,
				"display_name": String(random_entry.get("display_name", "随机角色")),
				"selection_order": -1,
				"type": int(random_entry.get("type", CharacterCatalogScript.TYPE_RANDOM_PLACEHOLDER)),
				"selection_icon_path": String(random_entry.get("selection_icon_path", "")),
				"selection_icon_selected_path": String(random_entry.get("selection_icon_selected_path", "")),
			})
	if entries.is_empty():
		var fallback_id := CharacterCatalogScript.get_default_character_id()
		var fallback_entry := CharacterCatalogScript.get_character_entry(fallback_id)
		entries.append({
			"id": fallback_id,
			"display_name": String(fallback_entry.get("display_name", fallback_id)),
			"selection_order": int(fallback_entry.get("selection_order", 999999)),
			"type": int(fallback_entry.get("type", 0)),
			"selection_icon_path": String(fallback_entry.get("selection_icon_path", "")),
			"selection_icon_selected_path": String(fallback_entry.get("selection_icon_selected_path", "")),
		})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var order_a := int(a.get("selection_order", 999999))
		var order_b := int(b.get("selection_order", 999999))
		if order_a == order_b:
			return String(a.get("display_name", "")).naturalnocasecmp_to(String(b.get("display_name", ""))) < 0
		return order_a < order_b
	)
	_formal_character_entries_cache_signature = cache_signature
	_formal_character_entries_cache = entries.duplicate(true)
	return entries


func _change_formal_character_page(delta: int) -> void:
	var entries := _get_formal_character_entries()
	_formal_character_page = clampi(_formal_character_page + delta, 0, _get_formal_character_max_page(entries.size()))
	_build_formal_character_buttons()
	_refresh_formal_loadout_selection(_last_room_view_model)


func _build_formal_character_grid_signature(entries: Array[Dictionary]) -> String:
	var ids := PackedStringArray()
	for entry in entries:
		ids.append(String(entry.get("id", "")))
	return "%s|%d|%d|%s|%s" % [_formal_character_category, _formal_character_page, _selected_team_id(), _selected_formal_character_id(), "|".join(ids)]


func _selected_formal_character_id() -> String:
	var selected_id := _selected_metadata(character_selector)
	if not selected_id.is_empty():
		return selected_id
	if _app_runtime != null and _app_runtime.player_profile_state != null:
		var profile_id := PlayerProfileState.resolve_default_character_id(String(_app_runtime.player_profile_state.default_character_id))
		if not profile_id.is_empty():
			return profile_id
	return CharacterCatalogScript.get_default_character_id()


func _formal_character_button_label(character_id: String) -> String:
	if character_id.length() <= 3:
		return character_id
	return character_id.substr(0, 3)


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
	_build_formal_character_buttons()
	_refresh_formal_loadout_selection(_last_room_view_model)
	_on_profile_selector_changed()


func _select_formal_team(team_id: int) -> void:
	_select_team_id(team_id)
	_build_formal_character_buttons()
	_refresh_formal_loadout_selection(_last_room_view_model)
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
	var can_edit_room := _can_edit_formal_room_properties(snapshot, view_model)
	if _formal_choose_mode_button != null:
		_formal_choose_mode_button.visible = is_custom_room and can_edit_room
		_formal_choose_mode_button.disabled = not can_edit_room
	if _formal_room_property_button != null:
		_formal_room_property_button.visible = is_custom_room and can_edit_room
		_formal_room_property_button.disabled = not can_edit_room
	if _formal_choose_map_button != null:
		_formal_choose_map_button.visible = is_custom_room and can_edit_room
		_formal_choose_map_button.disabled = not can_edit_room
	if _formal_room_name_label != null:
		_formal_room_name_label.text = "房间: %s" % String(view_model.get("room_display_name", view_model.get("title_text", "")))
	if _formal_room_mode_label != null:
		var mode_text := String(view_model.get("selected_mode_display_name", snapshot.mode_id))
		if is_custom_room:
			mode_text = _formal_display_mode
		if is_match_room:
			mode_text = "%s  %s" % [String(snapshot.queue_type), String(snapshot.match_format_id)]
		_formal_room_mode_label.text = "模式: %s" % mode_text
	var map_id := String(view_model.get("selected_map_id", snapshot.selected_map_id))
	var map_display_name := _resolve_formal_map_display_name(map_id)
	if _formal_room_map_label != null:
		_formal_room_map_label.text = "地图: %s" % map_display_name
	if _formal_room_member_label != null:
		_formal_room_member_label.text = "人数: %d / %d" % [snapshot.members.size(), _resolve_formal_open_slot_count(snapshot, view_model)]
	if _formal_map_preview_label != null:
		_formal_map_preview_label.text = map_display_name


func _can_edit_formal_room_properties(snapshot: RoomSnapshot = null, view_model: Dictionary = {}) -> bool:
	var resolved_snapshot := snapshot if snapshot != null else _last_room_snapshot
	var resolved_view_model := view_model if not view_model.is_empty() else _last_room_view_model
	return resolved_snapshot != null \
		and bool(resolved_view_model.get("is_custom_room", false)) \
		and bool(resolved_view_model.get("can_edit_selection", false)) \
		and _is_local_host(resolved_snapshot)


func _resolve_formal_map_display_name(map_id: String) -> String:
	var normalized_map_id := map_id.strip_edges()
	if normalized_map_id.is_empty():
		return "随机地图"
	var binding := MapSelectionCatalogScript.get_map_binding(normalized_map_id)
	if binding.is_empty():
		return normalized_map_id
	return String(binding.get("display_name", normalized_map_id))
