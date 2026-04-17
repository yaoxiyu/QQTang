class_name RoomSceneEventRouter
extends RefCounted

var _scene_controller: Node = null


func connect_ui_signals(scene_controller: Node) -> void:
	_scene_controller = scene_controller
	_connect_button("back_to_lobby_button", Callable(self, "_on_back_to_lobby_pressed"))
	_connect_button("leave_room_button", Callable(self, "_on_leave_room_pressed"))
	_connect_button("ready_button", Callable(self, "_on_ready_button_pressed"))
	_connect_button("start_button", Callable(self, "_on_start_button_pressed"))
	_connect_button("enter_queue_button", Callable(self, "_on_enter_queue_button_pressed"))
	_connect_button("cancel_queue_button", Callable(self, "_on_cancel_queue_button_pressed"))
	_connect_button("copy_invite_code_button", Callable(self, "_on_copy_invite_code_button_pressed"))
	_connect_button("add_opponent_button", Callable(self, "_on_add_opponent_pressed"))
	_connect_text_submit("player_name_input", Callable(self, "_on_player_name_submitted"))
	_connect_item_selected("team_selector", Callable(self, "_on_profile_selector_item_selected"))
	_connect_item_selected("character_selector", Callable(self, "_on_profile_selector_item_selected"))
	_connect_item_selected("character_skin_selector", Callable(self, "_on_profile_selector_item_selected"))
	_connect_item_selected("bubble_selector", Callable(self, "_on_profile_selector_item_selected"))
	_connect_item_selected("bubble_skin_selector", Callable(self, "_on_profile_selector_item_selected"))
	_connect_item_selected("game_mode_selector", Callable(self, "_on_mode_item_selected"))
	_connect_item_selected("map_selector", Callable(self, "_on_selection_item_selected"))
	_connect_item_selected("match_format_selector", Callable(self, "_on_match_format_item_selected"))
	_connect_multi_selected("match_mode_multi_select", Callable(self, "_on_match_mode_multi_selected"))


func _connect_button(property_name: String, callback: Callable) -> void:
	var button = _get_property(property_name)
	if button is Button and not button.pressed.is_connected(callback):
		button.pressed.connect(callback)


func _connect_text_submit(property_name: String, callback: Callable) -> void:
	var input = _get_property(property_name)
	if input is LineEdit and not input.text_submitted.is_connected(callback):
		input.text_submitted.connect(callback)


func _connect_item_selected(property_name: String, callback: Callable) -> void:
	var selector = _get_property(property_name)
	if selector is OptionButton and not selector.item_selected.is_connected(callback):
		selector.item_selected.connect(callback)


func _connect_multi_selected(property_name: String, callback: Callable) -> void:
	var selector = _get_property(property_name)
	if selector is ItemList and not selector.multi_selected.is_connected(callback):
		selector.multi_selected.connect(callback)


func _on_player_name_submitted(_text: String) -> void:
	_dispatch("_on_profile_changed")


func _on_profile_selector_item_selected(_index: int) -> void:
	_dispatch("_on_profile_selector_changed")


func _on_mode_item_selected(_index: int) -> void:
	_dispatch("_on_mode_selection_changed")


func _on_selection_item_selected(_index: int) -> void:
	_dispatch("_on_selection_changed")


func _on_match_format_item_selected(_index: int) -> void:
	_dispatch("_on_match_format_changed")


func _on_match_mode_multi_selected(_index: int, _selected: bool) -> void:
	_dispatch("_on_match_mode_multi_select_changed")


func _on_back_to_lobby_pressed() -> void:
	_dispatch("_on_back_to_lobby_pressed")


func _on_leave_room_pressed() -> void:
	_dispatch("_on_leave_room_pressed")


func _on_ready_button_pressed() -> void:
	_dispatch("_on_ready_button_pressed")


func _on_start_button_pressed() -> void:
	_dispatch("_on_start_button_pressed")


func _on_enter_queue_button_pressed() -> void:
	_dispatch("_on_enter_queue_button_pressed")


func _on_cancel_queue_button_pressed() -> void:
	_dispatch("_on_cancel_queue_button_pressed")


func _on_copy_invite_code_button_pressed() -> void:
	_dispatch("_on_copy_invite_code_button_pressed")


func _on_add_opponent_pressed() -> void:
	_dispatch("_on_add_opponent_pressed")


func _dispatch(method_name: String) -> void:
	if _scene_controller != null and _scene_controller.has_method(method_name):
		_scene_controller.call(method_name)


func _get_property(property_name: String):
	if _scene_controller == null:
		return null
	return _scene_controller.get(property_name)
