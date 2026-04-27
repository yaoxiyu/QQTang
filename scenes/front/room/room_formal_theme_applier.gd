extends "res://scenes/front/room/room_scene_controller_impl.gd"

func _create_formal_room_button(label_text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = label_text
	button.custom_minimum_size = Vector2(112, 42)
	_apply_room_button_style(button)
	button.pressed.connect(callback)
	return button



func _ensure_room_background() -> void:
	if room_root == null:
		return
	var background: ColorRect = room_root.get_node_or_null("FormalBackground")
	if background == null:
		background = ColorRect.new()
		background.name = "FormalBackground"
		room_root.add_child(background)
		room_root.move_child(background, 0)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.055, 0.095, 0.13, 1.0)
	background.set_meta("ui_asset_id", "ui.room.bg.main")


func _apply_room_card_style(card: PanelContainer) -> void:
	if card == null:
		return
	card.add_theme_stylebox_override("panel", _make_room_style(Color(0.12, 0.17, 0.22, 0.95), Color(0.30, 0.47, 0.62, 0.72), 8))
	card.set_meta("ui_asset_id", "ui.room.panel.config")


func _apply_room_button_style(button: Button) -> void:
	if button == null:
		return
	button.custom_minimum_size = Vector2(max(button.custom_minimum_size.x, 128.0), 40.0)
	button.add_theme_stylebox_override("normal", _make_room_style(Color(0.24, 0.32, 0.40, 1.0), Color(0.48, 0.64, 0.78, 0.85), 6))
	button.add_theme_stylebox_override("hover", _make_room_style(Color(0.32, 0.42, 0.52, 1.0), Color(0.64, 0.82, 0.98, 1.0), 6))
	button.add_theme_stylebox_override("pressed", _make_room_style(Color(0.16, 0.22, 0.28, 1.0), Color(0.56, 0.72, 0.88, 1.0), 6))


func _apply_room_small_button_style(button: Button) -> void:
	if button == null:
		return
	button.add_theme_stylebox_override("normal", _make_room_style(Color(0.24, 0.32, 0.40, 1.0), Color(0.48, 0.64, 0.78, 0.85), 4))
	button.add_theme_stylebox_override("hover", _make_room_style(Color(0.32, 0.42, 0.52, 1.0), Color(0.64, 0.82, 0.98, 1.0), 4))
	button.add_theme_stylebox_override("pressed", _make_room_style(Color(0.16, 0.22, 0.28, 1.0), Color(0.56, 0.72, 0.88, 1.0), 4))


func _apply_room_team_button_style(button: Button, fill_color: Color) -> void:
	if button == null:
		return
	button.add_theme_stylebox_override("normal", _make_room_style(fill_color, Color(0.26, 0.34, 0.42, 0.95), 4))
	button.add_theme_stylebox_override("hover", _make_room_style(fill_color.lightened(0.12), Color(0.86, 0.94, 1.0, 1.0), 4))
	button.add_theme_stylebox_override("pressed", _make_room_style(fill_color.darkened(0.14), Color(1.0, 0.96, 0.62, 1.0), 4))


func _apply_room_square_button_style(button: Button, fill_color: Color) -> void:
	if button == null:
		return
	var normal := _make_room_style(fill_color, Color(0.32, 0.52, 0.60, 0.9), 8)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", _make_room_style(fill_color.lightened(0.10), Color(0.70, 0.88, 0.96, 1.0), 8))
	button.add_theme_stylebox_override("pressed", _make_room_style(fill_color.darkened(0.14), Color(0.82, 0.92, 1.0, 1.0), 8))
	button.add_theme_stylebox_override("disabled", normal)


func _apply_room_input_style(input: LineEdit) -> void:
	if input == null:
		return
	input.custom_minimum_size = Vector2(max(input.custom_minimum_size.x, 220.0), 38.0)
	input.add_theme_stylebox_override("normal", _make_room_style(Color(0.07, 0.10, 0.13, 1.0), Color(0.26, 0.38, 0.50, 0.8), 6))
	input.add_theme_stylebox_override("focus", _make_room_style(Color(0.08, 0.12, 0.16, 1.0), Color(0.96, 0.76, 0.28, 1.0), 6))


func _apply_room_asset_ids() -> void:
	_set_room_asset_meta(room_root, "ui.room.bg.main")
	_set_room_asset_meta(summary_card, "ui.room.panel.config")
	_set_room_asset_meta(local_loadout_card, "ui.room.panel.loadout_preview")
	_set_room_asset_meta(room_selection_card, "ui.room.panel.map_select")
	_set_room_asset_meta(member_card, "ui.room.slot.occupied")
	_set_room_asset_meta(preview_card, "ui.room.preview.character_frame")
	_set_room_asset_meta(start_button, "ui.room.button.start.normal")
	_set_room_asset_meta(ready_button, "ui.room.button.ready.normal")
	_set_room_asset_meta(back_to_lobby_button, "ui.room.button.back.normal")


func _make_room_style(color: Color, border_color: Color, radius: int) -> StyleBoxFlat:
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


func _set_room_asset_meta(node: Node, asset_id: String) -> void:
	if node == null:
		return
	node.set_meta("ui_asset_id", asset_id)
