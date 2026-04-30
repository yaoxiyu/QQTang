extends "res://tests/gut/base/qqt_contract_test.gd"

const CharacterAnimationSetCatalogScript = preload("res://content/character_animation_sets/catalog/character_animation_set_catalog.gd")
const CharacterAnimationSetLoaderScript = preload("res://content/character_animation_sets/runtime/character_animation_set_loader.gd")
const CharacterLoaderScript = preload("res://content/characters/runtime/character_loader.gd")

const REQUIRED_PATHS := [
	"res://content/character_animation_sets/defs/character_animation_set_def.gd",
	"res://content/character_animation_sets/catalog/character_animation_set_catalog.gd",
	"res://content/character_animation_sets/runtime/character_animation_set_loader.gd",
	"res://content/character_animation_sets/runtime/character_animation_strip_loader.gd",
	"res://content/character_animation_sets/data/runtime_strips/character_animation_strip_sets.json",
	"res://content/character_animation_sets/data/sets/char_anim_qqt_10101.tres",
]

const REQUIRED_ANIMATIONS := [
	"idle_down",
	"idle_left",
	"idle_right",
	"idle_up",
	"run_down",
	"run_left",
	"run_right",
	"run_up",
	"dead_down",
	"defeat_down",
	"trigger_down",
	"wait_down",
	"win_down",
]


func test_main() -> void:
	_main_body()


func _main_body() -> void:
	_test_required_files_exist()
	_test_huoying_animation_set_contract()
	_test_huoying_presentation_contract()
	_test_runtime_team_variant_manifest_contract()


func _test_required_files_exist() -> void:
	for resource_path in REQUIRED_PATHS:
		_assert_true(ResourceLoader.exists(resource_path), "required resource exists: %s" % resource_path)


func _test_huoying_animation_set_contract() -> void:
	var animation_set := CharacterAnimationSetLoaderScript.load_animation_set("char_anim_qqt_10101")
	_assert_true(animation_set != null, "loader loads char_anim_qqt_10101")
	if animation_set == null:
		return
	_assert_true(animation_set.sprite_frames != null, "char_anim_qqt_10101 builds SpriteFrames from runtime strips")
	if animation_set.sprite_frames == null:
		return
	for animation_name in REQUIRED_ANIMATIONS:
		_assert_true(animation_set.sprite_frames.has_animation(animation_name), "SpriteFrames contains %s" % animation_name)
	for animation_name in ["dead_down", "defeat_down", "trigger_down", "win_down"]:
		_assert_true(
			animation_set.sprite_frames.get_animation_loop(animation_name),
			"SpriteFrames loops %s" % animation_name
		)


func _test_huoying_presentation_contract() -> void:
	var presentation := CharacterLoaderScript.load_character_presentation("10101")
	_assert_true(presentation != null, "CharacterLoader loads 10101 presentation")
	if presentation == null:
		return
	_assert_true(String(presentation.animation_set_id) == "char_anim_qqt_10101", "10101 presentation binds char_anim_qqt_10101")


func _test_runtime_team_variant_manifest_contract() -> void:
	_assert_true(
		not CharacterAnimationSetCatalogScript.has_id("char_anim_qqt_10101_team_01"),
		"team variants should stay out of eager catalog resources"
	)
	_assert_true(
		not ResourceLoader.exists("res://content/character_animation_sets/data/sets/char_anim_qqt_10101_team_01.tres"),
		"team variant tres should not be generated"
	)
	var team_variant := CharacterAnimationSetLoaderScript.load_animation_set("char_anim_qqt_10101_team_01")
	_assert_true(team_variant != null, "runtime manifest loads char_anim_qqt_10101_team_01")
	if team_variant != null:
		_assert_true(team_variant.sprite_frames.has_animation("run_down"), "team variant has run_down")
		_assert_true(team_variant.sprite_frames.has_animation("idle_down"), "team variant has idle_down")
		_assert_true(team_variant.sprite_frames.has_animation("wait_down"), "team variant has wait_down")
		_assert_true(team_variant.sprite_frames.get_animation_loop("dead_down"), "team variant loops dead_down")

	var team_marker := CharacterAnimationSetLoaderScript.load_animation_set("team_marker_leg1_team_01")
	_assert_true(team_marker != null, "runtime manifest loads team_marker_leg1_team_01")
	if team_marker != null:
		_assert_true(team_marker.sprite_frames.has_animation("run_down"), "team marker has run_down")
		_assert_true(team_marker.sprite_frames.has_animation("idle_down"), "team marker has idle_down")


func _assert_true(condition: bool, message: String) -> void:
	assert_true(condition, message)
