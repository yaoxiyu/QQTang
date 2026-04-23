extends RefCounted

const BubbleCatalogScript = preload("res://content/bubbles/catalog/bubble_catalog.gd")
const BubbleSkinCatalogScript = preload("res://content/bubble_skins/catalog/bubble_skin_catalog.gd")
const CharacterCatalogScript = preload("res://content/characters/catalog/character_catalog.gd")
const CharacterSkinCatalogScript = preload("res://content/character_skins/catalog/character_skin_catalog.gd")
const MapSelectionCatalogScript = preload("res://content/maps/catalog/map_selection_catalog.gd")
const LogFrontScript = preload("res://app/logging/log_front.gd")


func populate_selectors(controller: Node) -> void:
	controller._suppress_selection_callbacks = true
	populate_character_selector(controller)
	populate_team_selector(controller)
	populate_character_skin_selector(controller)
	populate_bubble_selector(controller)
	populate_bubble_skin_selector(controller)
	populate_mode_selector(controller)
	populate_map_selector(controller)
	populate_match_format_selector(controller, "casual")
	populate_match_mode_multi_select(controller, "casual", "1v1")
	controller._suppress_selection_callbacks = false


func populate_character_selector(controller: Node) -> void:
	if controller.character_selector == null:
		return
	controller.character_selector.clear()
	var owned_ids := _get_owned_ids(controller, "character")
	var added_count := 0
	for entry in CharacterCatalogScript.get_character_entries():
		var entry_id := String(entry.get("id", ""))
		if not _should_include_owned_entry(owned_ids, entry_id):
			continue
		controller.character_selector.add_item(String(entry.get("display_name", entry_id)))
		controller.character_selector.set_item_metadata(controller.character_selector.item_count - 1, entry_id)
		added_count += 1
	if added_count == 0:
		var fallback_id := _get_fallback_character_id(controller)
		controller.character_selector.add_item(fallback_id)
		controller.character_selector.set_item_metadata(controller.character_selector.item_count - 1, fallback_id)
	_log_room_scene("populate_character_selector", {
		"owned_character_count": owned_ids.size(),
		"catalog_character_count": CharacterCatalogScript.get_character_entries().size(),
		"selector_item_count": controller.character_selector.item_count,
		"added_count": added_count,
		"default_character_id": _get_fallback_character_id(controller),
		"owned_character_ids": owned_ids,
	})


func populate_team_selector(controller: Node, team_option_max: int = 2) -> void:
	if controller.team_selector == null:
		return
	controller.team_selector.clear()
	var max_team_id: int = max(2, team_option_max)
	for team_id in range(1, max_team_id + 1):
		controller.team_selector.add_item("Team %d" % team_id)
		controller.team_selector.set_item_metadata(controller.team_selector.item_count - 1, team_id)


func populate_character_skin_selector(controller: Node) -> void:
	if controller.character_skin_selector == null:
		return
	controller.character_skin_selector.clear()
	controller.character_skin_selector.add_item("None")
	controller.character_skin_selector.set_item_metadata(0, "")
	var owned_ids := _get_owned_ids(controller, "character_skin")
	for skin_def in CharacterSkinCatalogScript.get_all():
		if skin_def == null:
			continue
		if not _should_include_owned_entry(owned_ids, String(skin_def.skin_id)):
			continue
		controller.character_skin_selector.add_item(String(skin_def.display_name if not skin_def.display_name.is_empty() else skin_def.skin_id))
		controller.character_skin_selector.set_item_metadata(controller.character_skin_selector.item_count - 1, skin_def.skin_id)


func populate_bubble_selector(controller: Node) -> void:
	if controller.bubble_selector == null:
		return
	controller.bubble_selector.clear()
	var owned_ids := _get_owned_ids(controller, "bubble")
	var added_count := 0
	for entry in BubbleCatalogScript.get_bubble_entries():
		var entry_id := String(entry.get("id", ""))
		if not _should_include_owned_entry(owned_ids, entry_id):
			continue
		controller.bubble_selector.add_item(String(entry.get("display_name", entry_id)))
		controller.bubble_selector.set_item_metadata(controller.bubble_selector.item_count - 1, entry_id)
		added_count += 1
	if added_count == 0:
		var fallback_id := _get_fallback_bubble_id(controller)
		controller.bubble_selector.add_item(fallback_id)
		controller.bubble_selector.set_item_metadata(controller.bubble_selector.item_count - 1, fallback_id)


func populate_bubble_skin_selector(controller: Node) -> void:
	if controller.bubble_skin_selector == null:
		return
	controller.bubble_skin_selector.clear()
	controller.bubble_skin_selector.add_item("None")
	controller.bubble_skin_selector.set_item_metadata(0, "")
	var owned_ids := _get_owned_ids(controller, "bubble_skin")
	for skin_def in BubbleSkinCatalogScript.get_all():
		if skin_def == null:
			continue
		if not _should_include_owned_entry(owned_ids, String(skin_def.bubble_skin_id)):
			continue
		controller.bubble_skin_selector.add_item(String(skin_def.display_name if not skin_def.display_name.is_empty() else skin_def.bubble_skin_id))
		controller.bubble_skin_selector.set_item_metadata(controller.bubble_skin_selector.item_count - 1, skin_def.bubble_skin_id)


func populate_map_selector(controller: Node, mode_id: String = "") -> void:
	if controller.map_selector == null:
		return
	var current_value := selected_metadata(controller.map_selector)
	controller.map_selector.clear()
	var resolved_mode_id := mode_id
	if resolved_mode_id.is_empty():
		resolved_mode_id = selected_metadata(controller.game_mode_selector)
	for entry in MapSelectionCatalogScript.get_custom_room_maps_by_mode(resolved_mode_id):
		controller.map_selector.add_item(String(entry.get("display_name", entry.get("map_id", ""))))
		controller.map_selector.set_item_metadata(controller.map_selector.item_count - 1, String(entry.get("map_id", "")))
	select_metadata(controller.map_selector, current_value)


func populate_mode_selector(controller: Node) -> void:
	if controller.game_mode_selector == null:
		return
	var current_value := selected_metadata(controller.game_mode_selector)
	controller.game_mode_selector.clear()
	for entry in MapSelectionCatalogScript.get_custom_room_mode_entries():
		controller.game_mode_selector.add_item(String(entry.get("display_name", entry.get("mode_id", ""))))
		controller.game_mode_selector.set_item_metadata(controller.game_mode_selector.item_count - 1, String(entry.get("mode_id", "")))
	select_metadata(controller.game_mode_selector, current_value)


func populate_match_format_selector(controller: Node, queue_type: String) -> void:
	if controller.match_format_selector == null:
		return
	var current_value := selected_metadata(controller.match_format_selector)
	controller.match_format_selector.clear()
	for entry in MapSelectionCatalogScript.get_match_room_format_entries(queue_type):
		var match_format_id := String(entry.get("match_format_id", entry.get("id", "")))
		var display_name := String(entry.get("display_name", match_format_id))
		var enabled := bool(entry.get("enabled", false))
		if not enabled:
			display_name += " (Locked)"
		controller.match_format_selector.add_item(display_name)
		var index : int = controller.match_format_selector.item_count - 1
		controller.match_format_selector.set_item_metadata(index, match_format_id)
		controller.match_format_selector.set_item_disabled(index, not enabled)
	select_metadata(controller.match_format_selector, current_value if not current_value.is_empty() else "1v1")


func populate_match_mode_multi_select(
	controller: Node,
	queue_type: String,
	match_format_id: String,
	selected_mode_ids: Array[String] = []
) -> void:
	if controller.match_mode_multi_select == null:
		return
	controller.match_mode_multi_select.clear()
	for entry in MapSelectionCatalogScript.get_match_room_mode_entries(queue_type, match_format_id):
		var mode_id := String(entry.get("mode_id", entry.get("id", "")))
		controller.match_mode_multi_select.add_item(String(entry.get("display_name", mode_id)))
		var index : int = controller.match_mode_multi_select.item_count - 1
		controller.match_mode_multi_select.set_item_metadata(index, mode_id)
		if selected_mode_ids.has(mode_id) or selected_mode_ids.is_empty():
			controller.match_mode_multi_select.select(index, false)
	update_eligible_map_pool_hint(controller, queue_type, match_format_id)


func selected_metadata(selector: OptionButton) -> String:
	if selector == null or selector.selected < 0:
		return ""
	return String(selector.get_item_metadata(selector.selected))


func select_metadata(selector: OptionButton, value: String) -> void:
	if selector == null:
		return
	for index in range(selector.item_count):
		if String(selector.get_item_metadata(index)) == value:
			selector.select(index)
			return


func selected_team_id(controller: Node) -> int:
	if controller.team_selector == null or controller.team_selector.selected < 0:
		return 1
	return int(controller.team_selector.get_item_metadata(controller.team_selector.selected))


func select_team_id(controller: Node, team_id: int) -> void:
	if controller.team_selector == null:
		return
	for index in range(controller.team_selector.item_count):
		if int(controller.team_selector.get_item_metadata(index)) == team_id:
			controller.team_selector.select(index)
			return


func selected_match_mode_ids(controller: Node) -> Array[String]:
	var result: Array[String] = []
	if controller.match_mode_multi_select == null:
		return result
	for index in controller.match_mode_multi_select.get_selected_items():
		result.append(String(controller.match_mode_multi_select.get_item_metadata(index)))
	return result


func update_eligible_map_pool_hint(controller: Node, queue_type: String, match_format_id: String) -> void:
	if controller._room_scene_view_binder == null:
		return
	controller._room_scene_view_binder.update_eligible_map_pool_hint(controller, queue_type, match_format_id, selected_match_mode_ids(controller))


func _get_owned_ids(controller: Node, asset_type: String) -> Array[String]:
	if controller._app_runtime == null or controller._app_runtime.player_profile_state == null:
		return []
	var profile = controller._app_runtime.player_profile_state
	match asset_type:
		"character":
			return profile.owned_character_ids
		"character_skin":
			return profile.owned_character_skin_ids
		"bubble":
			return profile.owned_bubble_style_ids
		"bubble_skin":
			return profile.owned_bubble_skin_ids
		_:
			return []


func _should_include_owned_entry(owned_ids: Array[String], entry_id: String) -> bool:
	if owned_ids.is_empty():
		return false
	return owned_ids.has(entry_id)


func _get_fallback_character_id(controller: Node) -> String:
	if controller._app_runtime != null and controller._app_runtime.player_profile_state != null:
		var preferred_id := String(controller._app_runtime.player_profile_state.default_character_id)
		if not preferred_id.is_empty():
			return preferred_id
	for entry in CharacterCatalogScript.get_character_entries():
		var entry_id := String(entry.get("id", ""))
		if not entry_id.is_empty():
			return entry_id
	return "character_default"


func _get_fallback_bubble_id(controller: Node) -> String:
	if controller._app_runtime != null and controller._app_runtime.player_profile_state != null:
		var preferred_id := String(controller._app_runtime.player_profile_state.default_bubble_style_id)
		if not preferred_id.is_empty():
			return preferred_id
	for entry in BubbleCatalogScript.get_bubble_entries():
		var entry_id := String(entry.get("id", ""))
		if not entry_id.is_empty():
			return entry_id
	return "bubble_style_default"


func _log_room_scene(event_name: String, payload: Dictionary) -> void:
	LogFrontScript.debug("[room_scene_selector] %s %s" % [event_name, JSON.stringify(payload)], "", 0, "front.room.scene.selector")
