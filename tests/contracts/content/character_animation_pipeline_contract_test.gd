extends Node

const CharacterAnimationSetCatalogScript = preload("res://content/character_animation_sets/catalog/character_animation_set_catalog.gd")
const CharacterLoaderScript = preload("res://content/characters/runtime/character_loader.gd")

const REQUIRED_PATHS := [
	"res://content/character_animation_sets/defs/character_animation_set_def.gd",
	"res://content/character_animation_sets/catalog/character_animation_set_catalog.gd",
	"res://content/character_animation_sets/runtime/character_animation_set_loader.gd",
	"res://content/character_animation_sets/data/sets/char_anim_huoying.tres",
	"res://content/character_animation_sets/generated/sprite_frames/char_anim_huoying_frames.tres",
	"res://content/characters/data/presentation/char_pres_huoying.tres",
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
	"dead_left",
	"dead_right",
	"dead_up",
	"trapped_down",
	"victory_down",
	"defeat_down",
]


func _ready() -> void:
	run_all()


func run_all() -> void:
	_test_required_files_exist()
	_test_huoying_animation_set_contract()
	_test_huoying_presentation_contract()


func _test_required_files_exist() -> void:
	for resource_path in REQUIRED_PATHS:
		_assert_true(ResourceLoader.exists(resource_path), "required resource exists: %s" % resource_path)


func _test_huoying_animation_set_contract() -> void:
	var animation_set := CharacterAnimationSetCatalogScript.get_by_id("char_anim_huoying")
	_assert_true(animation_set != null, "catalog loads char_anim_huoying")
	if animation_set == null:
		return
	_assert_true(animation_set.sprite_frames != null, "char_anim_huoying has SpriteFrames")
	if animation_set.sprite_frames == null:
		return
	for animation_name in REQUIRED_ANIMATIONS:
		_assert_true(animation_set.sprite_frames.has_animation(animation_name), "SpriteFrames contains %s" % animation_name)


func _test_huoying_presentation_contract() -> void:
	var presentation := CharacterLoaderScript.load_character_presentation("char_huoying")
	_assert_true(presentation != null, "CharacterLoader loads char_huoying presentation")
	if presentation == null:
		return
	_assert_true(String(presentation.animation_set_id) == "char_anim_huoying", "char_huoying presentation binds char_anim_huoying")


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		print("[PASS] %s" % message)
		return
	push_error("[FAIL] %s" % message)
