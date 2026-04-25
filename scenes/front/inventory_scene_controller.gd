extends Node

const AppRuntimeRootScript = preload("res://app/flow/app_runtime_root.gd")
const InventoryViewModelBuilderScript = preload("res://app/front/inventory/inventory_view_model_builder.gd")

var _app_runtime: Node = null
var _builder = InventoryViewModelBuilderScript.new()
var _asset_list: ItemList = null
var _status_label: Label = null
var _equip_button: Button = null
var _detail_panel: PanelContainer = null


func _ready() -> void:
	_app_runtime = AppRuntimeRootScript.get_existing(get_tree())
	_build_ui()
	_refresh()


func _build_ui() -> void:
	var root: Control = get_node_or_null("InventoryRoot")
	if root == null:
		return
	_ensure_background(root, "ui.inventory.bg.main")
	var layout := VBoxContainer.new()
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.offset_left = 48
	layout.offset_top = 32
	layout.offset_right = -48
	layout.offset_bottom = -32
	layout.add_theme_constant_override("separation", 12)
	root.add_child(layout)
	root.set_meta("ui_asset_id", "ui.inventory.bg.main")

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	layout.add_child(header)
	var title := Label.new()
	title.text = "Inventory"
	title.add_theme_font_size_override("font_size", 32)
	header.add_child(title)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	var back := Button.new()
	back.text = "Back"
	_apply_button_style(back)
	back.pressed.connect(_on_back_pressed)
	header.add_child(back)

	_detail_panel = PanelContainer.new()
	_detail_panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.12, 0.17, 0.22, 0.94), Color(0.34, 0.50, 0.66, 0.75), 8))
	_detail_panel.set_meta("ui_asset_id", "ui.inventory.panel.grid")
	_detail_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(_detail_panel)
	var panel_vbox := VBoxContainer.new()
	panel_vbox.add_theme_constant_override("separation", 12)
	_detail_panel.add_child(panel_vbox)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	panel_vbox.add_child(tabs)
	for tab_text in ["角色", "皮肤", "泡泡", "头像", "称号"]:
		var tab := Button.new()
		tab.text = tab_text
		tab.custom_minimum_size = Vector2(88, 34)
		_apply_button_style(tab)
		tab.set_meta("ui_asset_id", "ui.inventory.tab.characters.normal")
		tabs.add_child(tab)

	_asset_list = ItemList.new()
	_asset_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_asset_list.max_columns = 4
	_asset_list.fixed_column_width = 180
	_asset_list.same_column_width = true
	_asset_list.custom_minimum_size = Vector2(0, 430)
	_asset_list.set_meta("ui_asset_id", "ui.inventory.card.asset.normal")
	panel_vbox.add_child(_asset_list)

	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 10)
	panel_vbox.add_child(action_row)
	_equip_button = Button.new()
	_equip_button.text = "Equip"
	_apply_button_style(_equip_button)
	_equip_button.set_meta("ui_asset_id", "ui.inventory.button.equip.normal")
	_equip_button.pressed.connect(_on_equip_pressed)
	action_row.add_child(_equip_button)

	_status_label = Label.new()
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	action_row.add_child(_status_label)


func _refresh() -> void:
	if _app_runtime == null or _app_runtime.inventory_use_case == null:
		_set_status("Inventory runtime missing")
		return
	var result: Dictionary = _app_runtime.inventory_use_case.refresh_inventory()
	if not bool(result.get("ok", false)):
		_set_status(String(result.get("user_message", "Inventory refresh failed")))
		return
	_render()


func _render() -> void:
	_asset_list.clear()
	var inventory = _app_runtime.inventory_use_case.get_current_inventory() if _app_runtime.inventory_use_case != null else null
	var view_model := _builder.build(inventory, _app_runtime.player_profile_state)
	for asset in view_model.get("assets", []):
		_asset_list.add_item(String(asset.get("label", "")))
		_asset_list.set_item_metadata(_asset_list.item_count - 1, asset)
	_set_status("Loaded %d asset(s)" % _asset_list.item_count)


func _on_equip_pressed() -> void:
	if _asset_list == null or _asset_list.get_selected_items().is_empty():
		_set_status("Select an asset")
		return
	var index := int(_asset_list.get_selected_items()[0])
	var asset: Dictionary = _asset_list.get_item_metadata(index)
	if not _can_equip(asset):
		_set_status("This asset type is not equipable yet")
		return
	var payload := _build_loadout_payload(asset)
	if _app_runtime.profile_gateway == null or not _app_runtime.profile_gateway.has_method("patch_loadout"):
		_set_status("Profile gateway missing")
		return
	var result: Dictionary = _app_runtime.profile_gateway.patch_loadout(_app_runtime.auth_session_state.access_token, payload)
	if not bool(result.get("ok", false)):
		_set_status(String(result.get("user_message", "Equip failed")))
		return
	_apply_profile_result(result)
	_set_status("Equipped")
	_render()


func _can_equip(asset: Dictionary) -> bool:
	return ["character", "character_skin", "bubble", "bubble_skin", "title", "avatar"].has(String(asset.get("asset_type", "")))


func _build_loadout_payload(asset: Dictionary) -> Dictionary:
	var profile = _app_runtime.player_profile_state
	var payload := {
		"default_character_id": profile.default_character_id,
		"default_character_skin_id": profile.default_character_skin_id,
		"default_bubble_style_id": profile.default_bubble_style_id,
		"default_bubble_skin_id": profile.default_bubble_skin_id,
		"avatar_id": profile.avatar_id,
		"title_id": profile.title_id,
	}
	match String(asset.get("asset_type", "")):
		"character":
			payload["default_character_id"] = String(asset.get("asset_id", ""))
		"character_skin":
			payload["default_character_skin_id"] = String(asset.get("asset_id", ""))
		"bubble":
			payload["default_bubble_style_id"] = String(asset.get("asset_id", ""))
		"bubble_skin":
			payload["default_bubble_skin_id"] = String(asset.get("asset_id", ""))
		"title":
			payload["title_id"] = String(asset.get("asset_id", ""))
		"avatar":
			payload["avatar_id"] = String(asset.get("asset_id", ""))
	return payload


func _apply_profile_result(result: Dictionary) -> void:
	var profile = _app_runtime.player_profile_state
	profile.default_character_id = String(result.get("default_character_id", profile.default_character_id))
	profile.default_character_skin_id = String(result.get("default_character_skin_id", profile.default_character_skin_id))
	profile.default_bubble_style_id = String(result.get("default_bubble_style_id", profile.default_bubble_style_id))
	profile.default_bubble_skin_id = String(result.get("default_bubble_skin_id", profile.default_bubble_skin_id))
	profile.avatar_id = String(result.get("avatar_id", profile.avatar_id))
	profile.title_id = String(result.get("title_id", profile.title_id))
	profile.profile_version = int(result.get("profile_version", profile.profile_version))


func _on_back_pressed() -> void:
	if _app_runtime != null and _app_runtime.front_flow != null:
		_app_runtime.front_flow.enter_lobby()


func _set_status(text: String) -> void:
	if _status_label != null:
		_status_label.text = text


func _ensure_background(root: Control, asset_id: String) -> void:
	var background := ColorRect.new()
	background.name = "FormalBackground"
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.06, 0.10, 0.14, 1.0)
	background.set_meta("ui_asset_id", asset_id)
	root.add_child(background)
	root.move_child(background, 0)


func _apply_button_style(button: Button) -> void:
	button.custom_minimum_size = Vector2(128, 40)
	button.add_theme_stylebox_override("normal", _make_panel_style(Color(0.80, 0.56, 0.18, 1.0), Color(1.0, 0.78, 0.32, 1.0), 6))
	button.add_theme_stylebox_override("hover", _make_panel_style(Color(0.92, 0.66, 0.22, 1.0), Color(1.0, 0.86, 0.46, 1.0), 6))
	button.add_theme_stylebox_override("pressed", _make_panel_style(Color(0.62, 0.40, 0.13, 1.0), Color(0.95, 0.72, 0.28, 1.0), 6))
	button.add_theme_color_override("font_color", Color(0.08, 0.08, 0.08, 1.0))


func _make_panel_style(color: Color, border_color: Color, radius: int) -> StyleBoxFlat:
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
	style.content_margin_left = 16.0
	style.content_margin_right = 16.0
	style.content_margin_top = 14.0
	style.content_margin_bottom = 14.0
	return style
