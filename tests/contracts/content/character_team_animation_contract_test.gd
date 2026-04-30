extends "res://tests/gut/base/qqt_contract_test.gd"

const CharacterTeamAnimationResolverScript = preload("res://content/character_animation_sets/runtime/character_team_animation_resolver.gd")
const CharacterAnimationSetLoaderScript = preload("res://content/character_animation_sets/runtime/character_animation_set_loader.gd")


func test_main() -> void:
	var base_id := "char_anim_phase38_demo_character"
	for team_id in range(1, 9):
		var resolved_id := CharacterTeamAnimationResolverScript.resolve_animation_set_id(base_id, team_id, true)
		_assert_true(resolved_id == "%s_team_%02d" % [base_id, team_id], "team %d resolves to team animation id" % team_id)
		var animation_set := CharacterAnimationSetLoaderScript.load_animation_set(resolved_id)
		_assert_true(animation_set != null, "loads %s" % resolved_id)
		if animation_set != null:
			_assert_true(animation_set.sprite_frames.has_animation("run_down"), "%s has run_down" % resolved_id)
			_assert_true(animation_set.sprite_frames.has_animation("trapped_down"), "%s has trapped_down" % resolved_id)
			_assert_true(animation_set.frame_width == 100, "%s frame width is 100" % resolved_id)
			_assert_true(animation_set.frame_height == 100, "%s frame height is 100" % resolved_id)


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)

