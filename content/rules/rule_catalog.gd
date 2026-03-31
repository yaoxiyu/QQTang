class_name RuleCatalog
extends RefCounted

const _RULE_ENTRIES := {
	"classic": {
		"rule_id": "classic",
		"display_name": "Classic",
		"description": "Standard free-for-all ruleset",
		"is_default": true,
	},
	"team": {
		"rule_id": "team",
		"display_name": "Team",
		"description": "Team-based elimination ruleset",
		"is_default": false,
	},
}


static func get_rule_ids() -> Array[String]:
	var rule_ids: Array[String] = []
	for rule_id in _RULE_ENTRIES.keys():
		rule_ids.append(String(rule_id))
	rule_ids.sort()
	return rule_ids


static func get_rule_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for rule_id in get_rule_ids():
		entries.append(get_rule_metadata(rule_id))
	return entries


static func has_rule(rule_id: String) -> bool:
	return _RULE_ENTRIES.has(rule_id)


static func get_rule_metadata(rule_id: String) -> Dictionary:
	if not has_rule(rule_id):
		return {}
	return _RULE_ENTRIES[rule_id].duplicate(true)


static func get_default_rule_id() -> String:
	for rule_id in get_rule_ids():
		if bool(_RULE_ENTRIES[rule_id].get("is_default", false)):
			return rule_id
	var rule_ids := get_rule_ids()
	if rule_ids.is_empty():
		return ""
	return rule_ids[0]
