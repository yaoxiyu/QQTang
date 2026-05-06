extends "res://scenes/front/room/room_scene_controller_impl.gd"

const ROOM_ASSETS := preload("res://content/ui_assets/room_assets.tres")

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
	var background := room_root.get_node_or_null("FormalBackground")
	if background == null:
		background = ColorRect.new()
		background.name = "FormalBackground"
		background.mouse_filter = Control.MOUSE_FILTER_IGNORE
		background.z_index = -1
		room_root.add_child(background)
		room_root.move_child(background, 0)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	var tex := load(ROOM_ASSETS.background_path)
	if tex:
		# Apply texture via shader-like approach: draw texture in a TextureRect inside
		var tex_rect := background.get_node_or_null("BgTexture")
		if tex_rect == null:
			tex_rect = TextureRect.new()
			tex_rect.name = "BgTexture"
			tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			tex_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
			tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tex_rect.stretch_mode = TextureRect.STRETCH_SCALE
			background.add_child(tex_rect)
		tex_rect.texture = tex
	background.color = Color.RED  # Fallback: keep RED to verify layering


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


func _apply_room_texture_button_style(button: Button, normal_path: String, hover_path: String, pressed_path: String, disabled_path: String) -> void:
	if button == null:
		return
	button.text = ""
	button.custom_minimum_size = Vector2(95, 35)
	button.add_theme_stylebox_override("normal", _make_texture_style(normal_path))
	button.add_theme_stylebox_override("hover", _make_texture_style(hover_path))
	button.add_theme_stylebox_override("pressed", _make_texture_style(pressed_path))
	button.add_theme_stylebox_override("disabled", _make_texture_style(disabled_path))


func _make_texture_style(texture_path: String) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = load(texture_path)
	return style


func _create_role_nav_button(is_left: bool, callback: Callable) -> Button:
	var button := Button.new()
	button.text = ""
	button.custom_minimum_size = Vector2(25, 120)
	var prefix := "left_role" if is_left else "right_role"
	var normal_path := ROOM_ASSETS.get("btn_%s_normal_path" % prefix) as String
	var hover_path := ROOM_ASSETS.get("btn_%s_hover_path" % prefix) as String
	var pressed_path := ROOM_ASSETS.get("btn_%s_pressed_path" % prefix) as String
	button.add_theme_stylebox_override("normal", _make_texture_style(normal_path))
	button.add_theme_stylebox_override("hover", _make_texture_style(hover_path))
	button.add_theme_stylebox_override("pressed", _make_texture_style(pressed_path))
	button.add_theme_stylebox_override("disabled", _make_texture_style(normal_path))
	var anim_frames: Array[String] = [
		ROOM_ASSETS.get("btn_%s_anim_0_path" % prefix) as String,
		ROOM_ASSETS.get("btn_%s_anim_1_path" % prefix) as String,
		ROOM_ASSETS.get("btn_%s_anim_2_path" % prefix) as String,
	]
	button.set_meta("role_anim_frames", anim_frames)
	button.set_meta("role_normal_path", normal_path)
	button.set_meta("role_hover_path", hover_path)
	button.set_meta("role_pressed_path", pressed_path)
	button.set_meta("role_animating", false)
	var anim_timer := Timer.new()
	anim_timer.name = "RoleAnimTimer"
	anim_timer.wait_time = 3.0
	anim_timer.one_shot = false
	anim_timer.autostart = true
	button.add_child(anim_timer)
	anim_timer.timeout.connect(_on_role_nav_anim_tick.bind(button))
	button.pressed.connect(callback)
	return button


func _on_role_nav_anim_tick(button: Button) -> void:
	if button.get_meta("role_animating", false):
		return
	button.set_meta("role_animating", true)
	var frames: Array = button.get_meta("role_anim_frames", [])
	_play_role_anim_frame(button, frames, 0)


func _play_role_anim_frame(button: Button, frames: Array, index: int) -> void:
	if index >= frames.size():
		button.set_meta("role_animating", false)
		button.add_theme_stylebox_override("normal", _make_texture_style(button.get_meta("role_normal_path")))
		button.add_theme_stylebox_override("hover", _make_texture_style(button.get_meta("role_hover_path")))
		button.add_theme_stylebox_override("pressed", _make_texture_style(button.get_meta("role_pressed_path")))
		return
	var anim_style := _make_texture_style(frames[index])
	button.add_theme_stylebox_override("normal", anim_style)
	button.add_theme_stylebox_override("hover", anim_style)
	button.add_theme_stylebox_override("pressed", anim_style)
	var frame_timer := Timer.new()
	frame_timer.name = "FrameTimer"
	frame_timer.wait_time = 0.166
	frame_timer.one_shot = true
	button.add_child(frame_timer)
	frame_timer.timeout.connect(Callable(self, "_play_role_anim_frame").bind(button, frames, index + 1))
	frame_timer.start()


func _apply_room_action_button_style(button: Button, prefix: String) -> void:
	if button == null:
		return
	button.text = ""
	button.custom_minimum_size = Vector2(114, 54)
	button.add_theme_stylebox_override("normal", _make_texture_style(ROOM_ASSETS.get("btn_%s_normal_path" % prefix) as String))
	button.add_theme_stylebox_override("hover", _make_texture_style(ROOM_ASSETS.get("btn_%s_hover_path" % prefix) as String))
	button.add_theme_stylebox_override("pressed", _make_texture_style(ROOM_ASSETS.get("btn_%s_pressed_path" % prefix) as String))
	button.add_theme_stylebox_override("disabled", _make_texture_style(ROOM_ASSETS.get("btn_%s_disabled_path" % prefix) as String))


func _apply_room_small_button_style(button: Button) -> void:
	if button == null:
		return
	button.add_theme_stylebox_override("normal", _make_room_style(Color(0.24, 0.32, 0.40, 1.0), Color(0.48, 0.64, 0.78, 0.85), 4))
	button.add_theme_stylebox_override("hover", _make_room_style(Color(0.32, 0.42, 0.52, 1.0), Color(0.64, 0.82, 0.98, 1.0), 4))
	button.add_theme_stylebox_override("pressed", _make_room_style(Color(0.16, 0.22, 0.28, 1.0), Color(0.56, 0.72, 0.88, 1.0), 4))
	button.add_theme_stylebox_override("hover_pressed", _make_room_style(Color(0.20, 0.28, 0.36, 1.0), Color(0.60, 0.78, 0.94, 1.0), 4))


func _apply_room_team_button_style(button: Button, fill_color: Color) -> void:
	if button == null:
		return
	button.add_theme_stylebox_override("normal", _make_room_style(fill_color, Color(0.26, 0.34, 0.42, 0.95), 4))
	button.add_theme_stylebox_override("hover", _make_room_style(fill_color.lightened(0.12), Color(0.86, 0.94, 1.0, 1.0), 4))
	button.add_theme_stylebox_override("pressed", _make_room_style(fill_color.darkened(0.14), Color(1.0, 0.96, 0.62, 1.0), 4))
	button.add_theme_stylebox_override("hover_pressed", _make_room_style(fill_color.darkened(0.02), Color(0.92, 0.95, 0.80, 1.0), 4))


func _apply_room_square_button_style(button: Button, fill_color: Color) -> void:
	if button == null:
		return
	var normal := _make_room_style(fill_color, Color(0.32, 0.52, 0.60, 0.9), 8)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", _make_room_style(fill_color.lightened(0.10), Color(0.70, 0.88, 0.96, 1.0), 8))
	button.add_theme_stylebox_override("pressed", _make_room_style(fill_color.darkened(0.14), Color(0.82, 0.92, 1.0, 1.0), 8))
	button.add_theme_stylebox_override("hover_pressed", _make_room_style(fill_color.lightened(0.02), Color(0.76, 0.90, 0.98, 1.0), 8))
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
