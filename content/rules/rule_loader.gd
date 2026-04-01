class_name RuleLoader
extends RefCounted

const RuleCatalogScript = preload("res://content/rules/rule_catalog.gd")


static func load_rule_config(rule_id: String) -> Dictionary:
	if rule_id.is_empty() or not RuleCatalogScript.has_rule(rule_id):
		push_error("RuleLoader.load_rule_config failed: unknown rule_id=%s" % rule_id)
		return {}

	var def_path := RuleCatalogScript.get_rule_def_path(rule_id)
	if def_path.is_empty():
		push_error("RuleLoader.load_rule_config failed: missing rule def path for rule_id=%s" % rule_id)
		return {}

	var rule_script := load(def_path)
	if rule_script == null:
		push_error("RuleLoader.load_rule_config failed: unable to load rule def script path=%s" % def_path)
		return {}
	if not rule_script.has_method("build"):
		push_error("RuleLoader.load_rule_config failed: rule def has no build() path=%s" % def_path)
		return {}

	var config_value = rule_script.build()
	if not (config_value is Dictionary):
		push_error("RuleLoader.load_rule_config failed: build() did not return Dictionary path=%s" % def_path)
		return {}

	var config: Dictionary = config_value
	if not _validate_rule_config(config):
		push_error("RuleLoader.load_rule_config failed: invalid rule config rule_id=%s" % rule_id)
		return {}

	return config.duplicate(true)


static func _validate_rule_config(config: Dictionary) -> bool:
	var rule_id := String(config.get("rule_id", ""))
	var display_name := String(config.get("display_name", ""))
	var round_time_sec := int(config.get("round_time_sec", 0))
	var starting_bomb_count := int(config.get("starting_bomb_count", 0))
	var starting_firepower := int(config.get("starting_firepower", 0))
	var starting_speed := int(config.get("starting_speed", 0))
	var victory_mode := String(config.get("victory_mode", ""))

	if rule_id.is_empty() or display_name.is_empty() or victory_mode.is_empty():
		return false
	if round_time_sec <= 0:
		return false
	if starting_bomb_count < 1:
		return false
	if starting_firepower < 1:
		return false
	if starting_speed < 1:
		return false
	return true
