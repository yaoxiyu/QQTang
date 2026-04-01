class_name RuleCatalog
extends RefCounted

const RULE_REGISTRY := {
	"classic": {
		"display_name": "经典模式",
		"def_path": "res://gameplay/config/rule_defs/classic_rule_def.gd",
		"is_default": true,
	}
}


static func get_rule_ids() -> Array[String]:
	var rule_ids: Array[String] = []
	for rule_id in RULE_REGISTRY.keys():
		rule_ids.append(String(rule_id))
	rule_ids.sort()
	return rule_ids


static func get_rule_entries() -> Array:
	var entries: Array = []
	for rule_id in get_rule_ids():
		var entry: Dictionary = RULE_REGISTRY[rule_id]
		var display_name := String(entry.get("display_name", rule_id))
		entries.append({
			"id": rule_id,
			"display_name": display_name
		})
	return entries


static func has_rule(rule_id: String) -> bool:
	return RULE_REGISTRY.has(rule_id)


static func get_rule_def_path(rule_id: String) -> String:
	if not has_rule(rule_id):
		return ""
	return String(RULE_REGISTRY[rule_id].get("def_path", ""))


static func get_rule_metadata(rule_id: String) -> Dictionary:
	var config := _load_rule_def_config(rule_id)
	if config.is_empty():
		return {}
	return config


static func get_default_rule_id() -> String:
	for rule_id in get_rule_ids():
		if bool(RULE_REGISTRY[rule_id].get("is_default", false)):
			return rule_id
	var rule_ids := get_rule_ids()
	if rule_ids.is_empty():
		return ""
	return rule_ids[0]


static func _load_rule_def_config(rule_id: String) -> Dictionary:
	if rule_id.is_empty() or not has_rule(rule_id):
		return {}
	var def_path := get_rule_def_path(rule_id)
	if def_path.is_empty():
		return {}
	var script := load(def_path)
	if script == null or not script.has_method("build"):
		return {}
	var built_config = script.build()
	if built_config is Dictionary:
		return (built_config as Dictionary).duplicate(true)
	return {}
