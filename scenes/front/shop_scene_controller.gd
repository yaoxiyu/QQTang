extends Node

const AppRuntimeRootScript = preload("res://app/flow/app_runtime_root.gd")
const ShopViewModelBuilderScript = preload("res://app/front/shop/shop_view_model_builder.gd")

var _app_runtime: Node = null
var _builder = ShopViewModelBuilderScript.new()
var _offer_list: ItemList = null
var _status_label: Label = null
var _buy_button: Button = null
var _detail_panel: PanelContainer = null


func _ready() -> void:
	_app_runtime = AppRuntimeRootScript.get_existing(get_tree())
	_build_ui()
	await _refresh()


func _build_ui() -> void:
	var root: Control = get_node_or_null("ShopRoot")
	if root == null:
		return
	_ensure_background(root, "ui.shop.bg.main")
	var layout := VBoxContainer.new()
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.offset_left = 48
	layout.offset_top = 32
	layout.offset_right = -48
	layout.offset_bottom = -32
	layout.add_theme_constant_override("separation", 12)
	root.add_child(layout)
	root.set_meta("ui_asset_id", "ui.shop.bg.main")

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	layout.add_child(header)
	var title := Label.new()
	title.text = "Shop"
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
	_detail_panel.set_meta("ui_asset_id", "ui.shop.panel.detail")
	_detail_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(_detail_panel)
	var panel_vbox := VBoxContainer.new()
	panel_vbox.add_theme_constant_override("separation", 12)
	_detail_panel.add_child(panel_vbox)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	panel_vbox.add_child(tabs)
	for tab_text in ["角色", "皮肤", "泡泡", "推荐"]:
		var tab := Button.new()
		tab.text = tab_text
		tab.custom_minimum_size = Vector2(96, 34)
		_apply_button_style(tab)
		tab.set_meta("ui_asset_id", "ui.shop.tab.characters.normal")
		tabs.add_child(tab)

	_offer_list = ItemList.new()
	_offer_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_offer_list.max_columns = 3
	_offer_list.fixed_column_width = 260
	_offer_list.same_column_width = true
	_offer_list.custom_minimum_size = Vector2(0, 420)
	_offer_list.set_meta("ui_asset_id", "ui.shop.card.offer.normal")
	panel_vbox.add_child(_offer_list)

	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 10)
	panel_vbox.add_child(action_row)
	_buy_button = Button.new()
	_buy_button.text = "Buy"
	_apply_button_style(_buy_button)
	_buy_button.set_meta("ui_asset_id", "ui.shop.button.buy.normal")
	_buy_button.pressed.connect(_on_buy_pressed)
	action_row.add_child(_buy_button)

	_status_label = Label.new()
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.set_meta("ui_asset_id", "ui.shop.toast.error")
	action_row.add_child(_status_label)


func _refresh() -> void:
	if _app_runtime == null or _app_runtime.shop_use_case == null:
		_set_status("Shop runtime missing")
		return
	if _app_runtime.wallet_use_case != null:
		await _app_runtime.wallet_use_case.refresh_wallet()
	if _app_runtime.inventory_use_case != null:
		await _app_runtime.inventory_use_case.refresh_inventory()
	var result: Dictionary = await _app_runtime.shop_use_case.refresh_catalog()
	if not bool(result.get("ok", false)):
		_set_status(String(result.get("user_message", "Shop refresh failed")))
		return
	_render()


func _render() -> void:
	if _offer_list == null:
		return
	_offer_list.clear()
	var wallet = _app_runtime.wallet_use_case.get_current_wallet() if _app_runtime.wallet_use_case != null else null
	var inventory = _app_runtime.inventory_use_case.get_current_inventory() if _app_runtime.inventory_use_case != null else null
	var catalog = _app_runtime.shop_use_case.current_catalog
	var view_model := _builder.build(catalog, wallet, inventory)
	for offer in view_model.get("offers", []):
		_offer_list.add_item(String(offer.get("label", "")))
		_offer_list.set_item_metadata(_offer_list.item_count - 1, offer)
	_set_status("Loaded %d offer(s)" % _offer_list.item_count)


func _on_buy_pressed() -> void:
	if _offer_list == null or _offer_list.get_selected_items().is_empty():
		_set_status("Select an offer")
		return
	var index := int(_offer_list.get_selected_items()[0])
	var offer: Dictionary = _offer_list.get_item_metadata(index)
	if bool(offer.get("owned", false)):
		_set_status("Already owned")
		return
	var result: Dictionary = await _app_runtime.shop_use_case.purchase_offer(String(offer.get("offer_id", "")))
	if not bool(result.get("ok", false)):
		_set_status(String(result.get("user_message", "Purchase failed")))
		return
	var purchase = result.get("purchase", null)
	if purchase != null:
		if _app_runtime.wallet_use_case != null:
			_app_runtime.wallet_use_case.current_wallet = purchase.wallet
		if _app_runtime.inventory_use_case != null:
			_app_runtime.inventory_use_case.current_inventory = purchase.inventory
	_set_status("Purchase completed")
	await _render()


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
