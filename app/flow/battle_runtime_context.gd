class_name BattleRuntimeContext
extends RefCounted

var current_room_snapshot = null
var current_start_config = null
var current_battle_content_manifest: Dictionary = {}
var current_battle_scene: Node = null
var current_battle_bootstrap: Node = null
var current_presentation_bridge: Node = null
var current_battle_hud_controller: Node = null
var current_battle_camera_controller: Node = null
var current_settlement_controller: Node = null
var current_settlement_popup_summary: Dictionary = {}


func clear_battle_payload() -> void:
	current_room_snapshot = null
	current_start_config = null
	current_battle_content_manifest = {}
	current_battle_scene = null
	current_battle_bootstrap = null
	current_presentation_bridge = null
	current_battle_hud_controller = null
	current_battle_camera_controller = null
	current_settlement_controller = null
	current_settlement_popup_summary = {}
