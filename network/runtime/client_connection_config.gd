class_name ClientConnectionConfig
extends RefCounted

const CharacterCatalogScript = preload("res://content/characters/catalog/character_catalog.gd")
const BubbleCatalogScript = preload("res://content/bubbles/catalog/bubble_catalog.gd")
const ModeCatalogScript = preload("res://content/modes/catalog/mode_catalog.gd")

var server_host: String = "127.0.0.1"
var server_port: int = 9000
var connect_timeout_sec: float = 5.0
var room_id_hint: String = ""
var player_name: String = "Player1"
var selected_character_id: String = CharacterCatalogScript.get_default_character_id()
var selected_bubble_style_id: String = BubbleCatalogScript.get_default_bubble_id()
var selected_mode_id: String = ModeCatalogScript.get_default_mode_id()


func to_dict() -> Dictionary:
	return {
		"server_host": server_host,
		"server_port": server_port,
		"connect_timeout_sec": connect_timeout_sec,
		"room_id_hint": room_id_hint,
		"player_name": player_name,
		"selected_character_id": selected_character_id,
		"selected_bubble_style_id": selected_bubble_style_id,
		"selected_mode_id": selected_mode_id,
	}


func duplicate_deep() -> ClientConnectionConfig:
	var duplicated := ClientConnectionConfig.new()
	duplicated.server_host = server_host
	duplicated.server_port = server_port
	duplicated.connect_timeout_sec = connect_timeout_sec
	duplicated.room_id_hint = room_id_hint
	duplicated.player_name = player_name
	duplicated.selected_character_id = selected_character_id
	duplicated.selected_bubble_style_id = selected_bubble_style_id
	duplicated.selected_mode_id = selected_mode_id
	return duplicated
