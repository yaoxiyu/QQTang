extends "res://tests/gut/base/qqt_integration_test.gd"

const BattleItemConfigBuilderScript = preload("res://gameplay/battle/config/battle_item_config_builder.gd")


func test_main() -> void:
	var ok := _test_rule_profiles_resolve_to_distinct_drop_configs()


func _test_rule_profiles_resolve_to_distinct_drop_configs() -> bool:
	var builder = BattleItemConfigBuilderScript.new()
	var classic := builder.build_for_rule("classic", "default_items")
	var classic_plus := builder.build_for_rule("classic_plus", "default_items")
	var quick_match := builder.build_for_rule("quick_match", "default_items")
	var prefix := "rule_drop_profile_probe_test"
	var ok := true

	ok = qqt_check(String(classic.get("profile_id", "")) == "default_items", "classic should use default_items profile", prefix) and ok
	ok = qqt_check(String(classic_plus.get("profile_id", "")) == "classic_plus_items", "classic_plus should use classic_plus_items profile", prefix) and ok
	ok = qqt_check(String(quick_match.get("profile_id", "")) == "quick_match_items", "quick_match should use quick_match_items profile", prefix) and ok
	ok = qqt_check(
		str(classic_plus.get("drop_pool", [])) != str(quick_match.get("drop_pool", [])),
		"classic_plus and quick_match should produce different weighted drop pools",
		prefix
	) and ok
	ok = qqt_check(
		int(classic.get("empty_weight", -1)) != int(quick_match.get("empty_weight", -1)),
		"classic and quick_match should not share the same empty drop weight",
		prefix
	) and ok
	return ok

