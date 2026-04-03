class_name BubbleCatalog
extends RefCounted

const BUBBLE_REGISTRY := {
	"bubble_default": {
		"display_name": "默认泡泡",
		"style_resource_path": "res://content/bubbles/resources/bubble_default_style.tres",
		"gameplay_resource_path": "res://content/bubbles/resources/bubble_default_gameplay.tres",
		"is_default": true,
	},
	"bubble_runner": {
		"display_name": "疾跑泡泡",
		"style_resource_path": "res://content/bubbles/resources/bubble_runner_style.tres",
		"gameplay_resource_path": "res://content/bubbles/resources/bubble_default_gameplay.tres",
	},
}


static func get_bubble_ids() -> Array[String]:
	var bubble_ids: Array[String] = []
	for bubble_id in BUBBLE_REGISTRY.keys():
		bubble_ids.append(String(bubble_id))
	bubble_ids.sort()
	return bubble_ids


static func get_default_bubble_id() -> String:
	for bubble_id in get_bubble_ids():
		if bool(BUBBLE_REGISTRY[bubble_id].get("is_default", false)):
			return bubble_id
	var bubble_ids := get_bubble_ids()
	if bubble_ids.is_empty():
		return ""
	return bubble_ids[0]


static func has_bubble(bubble_id: String) -> bool:
	return BUBBLE_REGISTRY.has(bubble_id)


static func get_bubble_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for bubble_id in get_bubble_ids():
		if not has_bubble(bubble_id):
			continue
		var entry: Dictionary = BUBBLE_REGISTRY[bubble_id]
		entries.append({
			"id": bubble_id,
			"display_name": String(entry.get("display_name", bubble_id)),
			"style_resource_path": String(entry.get("style_resource_path", "")),
			"gameplay_resource_path": String(entry.get("gameplay_resource_path", "")),
			"is_default": bool(entry.get("is_default", false)),
		})
	return entries


static func get_style_resource_path(bubble_id: String) -> String:
	if not has_bubble(bubble_id):
		return ""
	return String(BUBBLE_REGISTRY[bubble_id].get("style_resource_path", ""))


static func get_gameplay_resource_path(bubble_id: String) -> String:
	if not has_bubble(bubble_id):
		return ""
	return String(BUBBLE_REGISTRY[bubble_id].get("gameplay_resource_path", ""))
