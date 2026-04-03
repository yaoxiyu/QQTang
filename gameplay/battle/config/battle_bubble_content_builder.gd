class_name BattleBubbleContentBuilder
extends RefCounted

const BubbleLoaderScript = preload("res://content/bubbles/runtime/bubble_loader.gd")


func build_for_start_config(start_config: BattleStartConfig) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if start_config == null:
		return entries
	for loadout in start_config.player_bubble_loadouts:
		var bubble_style_id := String(loadout.get("bubble_style_id", ""))
		var metadata := BubbleLoaderScript.load_metadata(bubble_style_id)
		if metadata.is_empty():
			continue
		var entry := {
			"peer_id": int(loadout.get("peer_id", -1)),
			"bubble_style_id": String(metadata.get("bubble_style_id", bubble_style_id)),
			"display_name": String(metadata.get("display_name", "")),
			"icon_path": String(metadata.get("icon_path", "")),
			"bubble_scene_path": String(metadata.get("bubble_scene_path", "")),
			"content_hash": String(metadata.get("content_hash", "")),
		}
		entries.append(entry)
	return entries
