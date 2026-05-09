extends "res://scenes/front/room/room_formal_layout_builder.gd"

const RoomTooltipAssets = preload("res://content/ui_assets/room_tooltip_assets.tres")
const TOOLTIP_TAG := "front.room.tooltip"

const FORMAL_RANDOM_CHARACTER_ID := "12301"
const TOOLTIP_ILL_W := 256.0
const TOOLTIP_ILL_H := 271.0

var _formal_character_grid_signature: String = ""
var _formal_character_entries_cache_signature: String = ""
var _formal_character_entries_cache: Array[Dictionary] = []
var _formal_character_icon_cache: Dictionary = {}
var _character_tooltip: Control = null
var _tooltip_character_id: String = ""


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
		button.set_meta("icon_path", String(entry.get("selection_icon_path", "")))
		button.set_meta("icon_selected_path", String(entry.get("selection_icon_selected_path", "")))
		button.tooltip_text = String(entry.get("display_name", character_id))
		_apply_room_square_button_style(button, Color(0.33, 0.72, 0.86, 0.95))
		_add_formal_character_icon(button, entry, character_id == _selected_formal_character_id())
		button.pressed.connect(Callable(self, "_select_formal_character").bind(character_id))
		button.mouse_entered.connect(Callable(self, "_on_character_button_hovered").bind(button, true))
		button.mouse_exited.connect(Callable(self, "_on_character_button_hovered").bind(button, false))
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


func _add_formal_character_preview(parent: Control, character_id: String, size: float, team_id: int = 0) -> void:
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
		preview.call_deferred("configure_preview", character_id, team_id)


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


func _on_character_button_hovered(button: Button, hovered: bool) -> void:
	var texture_rect := _find_character_button_texture_rect(button)
	if texture_rect == null:
		return
	if hovered:
		var selected_path := String(button.get_meta("icon_selected_path", ""))
		if not selected_path.is_empty():
			var texture := _load_formal_character_icon(selected_path)
			if texture != null:
				texture_rect.texture = texture
		var character_id := String(button.get_meta("character_id", ""))
		if not character_id.is_empty() and character_id != FORMAL_RANDOM_CHARACTER_ID:
			_show_character_tooltip(character_id)
	else:
		if not button.button_pressed:
			var normal_path := String(button.get_meta("icon_path", ""))
			if not normal_path.is_empty():
				var texture := _load_formal_character_icon(normal_path)
				if texture != null:
					texture_rect.texture = texture
		_hide_character_tooltip()


func _find_character_button_texture_rect(button: Button) -> TextureRect:
	for child in button.get_children():
		if child is TextureRect:
			return child as TextureRect
	return null


func _ensure_character_tooltip() -> void:
	if _character_tooltip != null:
		return
	_character_tooltip = Control.new()
	_character_tooltip.name = "CharacterTooltip"
	_character_tooltip.visible = false
	_character_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_character_tooltip.z_index = 100
	_character_tooltip.custom_minimum_size = Vector2(TOOLTIP_ILL_W, TOOLTIP_ILL_H)
	if room_root != null:
		room_root.add_child(_character_tooltip)


func _show_character_tooltip(character_id: String) -> void:
	if character_id == _tooltip_character_id and _character_tooltip != null and _character_tooltip.visible:
		return
	_ensure_character_tooltip()
	if _character_tooltip == null:
		return
	for child in _character_tooltip.get_children():
		child.queue_free()
	var metadata := CharacterCatalogScript.get_character_metadata(character_id)
	if metadata.is_empty():
		return
	_tooltip_character_id = character_id
	var child_count := 0

	var ill_path := String(metadata.get("illustration_path", ""))
	if not ill_path.is_empty():
		var ill_texture := _load_formal_character_icon(ill_path)
		if ill_texture != null:
			var ill_rect := TextureRect.new()
			ill_rect.texture = ill_texture
			ill_rect.size = ill_texture.get_size()
			ill_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			ill_rect.set_position(RoomTooltipAssets.illustration_offset)
			_character_tooltip.add_child(ill_rect)
			child_count += 1

	var panel_texture := _load_formal_character_icon(RoomTooltipAssets.panel_background_path)
	if panel_texture != null:
		var panel_rect := TextureRect.new()
		panel_rect.texture = panel_texture
		panel_rect.size = panel_texture.get_size()
		panel_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel_rect.set_position(RoomTooltipAssets.panel_offset)
		_character_tooltip.add_child(panel_rect)
		child_count += 1

	var name_path := String(metadata.get("name_image_path", ""))
	if not name_path.is_empty():
		var name_texture := _load_formal_character_icon(name_path)
		if name_texture != null:
			var name_rect := TextureRect.new()
			name_rect.texture = name_texture
			name_rect.size = name_texture.get_size()
			name_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			name_rect.set_position(RoomTooltipAssets.panel_offset + RoomTooltipAssets.name_offset)
			_character_tooltip.add_child(name_rect)
			child_count += 1

	var initial_bomb := int(metadata.get("initial_bubble_count", 1))
	var max_bomb := int(metadata.get("max_bubble_count", 5))
	var initial_power := int(metadata.get("initial_bubble_power", 1))
	var max_power := int(metadata.get("max_bubble_power", 5))
	var initial_speed := int(metadata.get("initial_move_speed", 1))
	var max_speed := int(metadata.get("max_move_speed", 9))
	_add_tooltip_stat_icons(RoomTooltipAssets.bomb_icon_path, initial_bomb, max_bomb, 0)
	_add_tooltip_stat_icons(RoomTooltipAssets.power_icon_path, initial_power, max_power, 1)
	_add_tooltip_stat_icons(RoomTooltipAssets.speed_icon_path, initial_speed, max_speed, 2)

	if _formal_character_grid != null and room_root != null:
		var grid_pos := _formal_character_grid.global_position
		var root_pos := room_root.global_position
		_character_tooltip.set_position(Vector2(grid_pos.x - root_pos.x, grid_pos.y - root_pos.y) + RoomTooltipAssets.tooltip_anchor_offset)

	_character_tooltip.visible = true
	LogFrontScript.debug("[tooltip] show char=%s children=%d pos=%s" % [character_id, child_count, _character_tooltip.position], "", 0, TOOLTIP_TAG)


func _hide_character_tooltip() -> void:
	_tooltip_character_id = ""
	if _character_tooltip != null:
		_character_tooltip.visible = false


func _add_tooltip_stat_icons(icon_path: String, initial: int, max_val: int, row_index: int) -> void:
	if _character_tooltip == null:
		return
	var filled_texture := _load_formal_character_icon(icon_path)
	if filled_texture == null:
		return
	var max_icons := mini(max_val, RoomTooltipAssets.max_stat_icons)
	var filled_count := clampi(initial, 0, max_icons)
	var dim_count := max_icons - filled_count
	var row_origin := RoomTooltipAssets.panel_offset + RoomTooltipAssets.stat_offset + Vector2(0, float(row_index) * RoomTooltipAssets.stat_row_gap)
	for i in range(filled_count):
		var icon := TextureRect.new()
		icon.texture = filled_texture
		icon.size = filled_texture.get_size()
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.set_position(row_origin + Vector2(float(i) * RoomTooltipAssets.stat_icon_step, 0))
		_character_tooltip.add_child(icon)
	for i in range(dim_count):
		var icon := TextureRect.new()
		icon.texture = filled_texture
		icon.size = filled_texture.get_size()
		icon.modulate = Color(1, 1, 1, RoomTooltipAssets.stat_dim_alpha)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.set_position(row_origin + Vector2(float(filled_count + i) * RoomTooltipAssets.stat_icon_step, 0))
		_character_tooltip.add_child(icon)


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
	var current_team := _selected_team_id()
	for child in _formal_team_row.get_children():
		if child is Button:
			(child as Button).button_pressed = int(child.get_meta("team_id", 0)) == current_team


func _select_formal_character(character_id: String) -> void:
	_select_metadata(character_selector, character_id)
	_build_formal_character_buttons()
	_refresh_formal_loadout_selection(_last_room_view_model)
	_on_profile_selector_changed()


func _select_formal_team(team_id: int) -> void:
	_select_team_id(team_id)
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
		_formal_choose_mode_button.visible = is_custom_room
		_formal_choose_mode_button.disabled = not can_edit_room
	if _formal_room_property_button != null:
		_formal_room_property_button.visible = is_custom_room
		_formal_room_property_button.disabled = not can_edit_room
	if _formal_choose_map_button != null:
		_formal_choose_map_button.visible = is_custom_room
		_formal_choose_map_button.disabled = not can_edit_room


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
