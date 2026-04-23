class_name ClientConnectionConfig
extends RefCounted

const CharacterCatalogScript = preload("res://content/characters/catalog/character_catalog.gd")
const CharacterSkinCatalogScript = preload("res://content/character_skins/catalog/character_skin_catalog.gd")
const BubbleCatalogScript = preload("res://content/bubbles/catalog/bubble_catalog.gd")
const BubbleSkinCatalogScript = preload("res://content/bubble_skins/catalog/bubble_skin_catalog.gd")
const MapCatalogScript = preload("res://content/maps/catalog/map_catalog.gd")
const MatchFormatCatalogScript = preload("res://content/match_formats/catalog/match_format_catalog.gd")
const ModeCatalogScript = preload("res://content/modes/catalog/mode_catalog.gd")
const RuleSetCatalogScript = preload("res://content/rulesets/catalog/rule_set_catalog.gd")

var server_host: String = "127.0.0.1"
var server_port: int = 9100
var connect_timeout_sec: float = 5.0
var room_id_hint: String = ""
var room_kind: String = "private_room"
var room_display_name: String = ""
var room_ticket: String = ""
var room_ticket_id: String = ""
var account_id: String = ""
var profile_id: String = ""
var device_session_id: String = ""
var player_name: String = "Player1"
var selected_character_id: String = CharacterCatalogScript.get_default_character_id()
var selected_character_skin_id: String = ""
var selected_bubble_style_id: String = BubbleCatalogScript.get_default_bubble_id()
var selected_bubble_skin_id: String = ""
var selected_map_id: String = MapCatalogScript.get_default_map_id()
var selected_rule_set_id: String = RuleSetCatalogScript.get_default_rule_id()
var selected_mode_id: String = ModeCatalogScript.get_default_mode_id()
var match_format_id: String = MatchFormatCatalogScript.get_default_match_format_id()
var selected_mode_ids: Array[String] = []


func to_dict() -> Dictionary:
	return {
		"server_host": server_host,
		"server_port": server_port,
		"connect_timeout_sec": connect_timeout_sec,
		"room_id_hint": room_id_hint,
		"room_kind": room_kind,
		"room_display_name": room_display_name,
		"room_ticket": room_ticket,
		"room_ticket_id": room_ticket_id,
		"account_id": account_id,
		"profile_id": profile_id,
		"device_session_id": device_session_id,
		"player_name": player_name,
		"selected_character_id": selected_character_id,
		"selected_character_skin_id": selected_character_skin_id,
		"selected_bubble_style_id": selected_bubble_style_id,
		"selected_bubble_skin_id": selected_bubble_skin_id,
		"selected_map_id": selected_map_id,
		"selected_rule_set_id": selected_rule_set_id,
		"selected_mode_id": selected_mode_id,
		"match_format_id": match_format_id,
		"selected_mode_ids": selected_mode_ids.duplicate(),
	}


func duplicate_deep() -> ClientConnectionConfig:
	var duplicated := ClientConnectionConfig.new()
	duplicated.server_host = server_host
	duplicated.server_port = server_port
	duplicated.connect_timeout_sec = connect_timeout_sec
	duplicated.room_id_hint = room_id_hint
	duplicated.room_kind = room_kind
	duplicated.room_display_name = room_display_name
	duplicated.room_ticket = room_ticket
	duplicated.room_ticket_id = room_ticket_id
	duplicated.account_id = account_id
	duplicated.profile_id = profile_id
	duplicated.device_session_id = device_session_id
	duplicated.player_name = player_name
	duplicated.selected_character_id = selected_character_id
	duplicated.selected_character_skin_id = selected_character_skin_id
	duplicated.selected_bubble_style_id = selected_bubble_style_id
	duplicated.selected_bubble_skin_id = selected_bubble_skin_id
	duplicated.selected_map_id = selected_map_id
	duplicated.selected_rule_set_id = selected_rule_set_id
	duplicated.selected_mode_id = selected_mode_id
	duplicated.match_format_id = match_format_id
	duplicated.selected_mode_ids = selected_mode_ids.duplicate()
	return duplicated
