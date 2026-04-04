extends Node

const BattlePlayerActorViewScript = preload("res://presentation/battle/actors/player_actor_view.gd")
const BattlePlayerVisualProfileScript = preload("res://presentation/battle/actors/battle_player_visual_profile.gd")
const CharacterLoaderScript = preload("res://content/characters/runtime/character_loader.gd")
const CharacterAnimationSetLoaderScript = preload("res://content/character_animation_sets/runtime/character_animation_set_loader.gd")
const CharacterSkinCatalogScript = preload("res://content/character_skins/catalog/character_skin_catalog.gd")


func _ready() -> void:
	run_all()


func run_all() -> void:
	_test_player_actor_binds_character_animation_set()


func _test_player_actor_binds_character_animation_set() -> void:
	var actor_view = BattlePlayerActorViewScript.new()
	add_child(actor_view)

	var profile = BattlePlayerVisualProfileScript.new()
	profile.player_slot = 0
	profile.character_id = "char_huoying"
	profile.character_presentation = CharacterLoaderScript.load_character_presentation("char_huoying")
	profile.character_skin = CharacterSkinCatalogScript.get_by_id("skin_gold")
	profile.animation_set = CharacterAnimationSetLoaderScript.load_animation_set("char_anim_huoying")

	_assert_true(profile.character_presentation != null, "profile loads char_pres_huoying")
	_assert_true(profile.character_skin != null, "profile loads skin_gold")
	_assert_true(profile.animation_set != null, "profile loads char_anim_huoying")

	actor_view.configure_visual_profile(profile)
	var body_view = actor_view.get("_body_view") as Node2D
	_assert_true(body_view != null, "actor view creates _body_view")
	_assert_true(body_view != null and body_view is Node2D, "_body_view is Node2D")
	if body_view == null:
		actor_view.free()
		return

	var body_sprite := body_view.get_node_or_null("BodySprite") as AnimatedSprite2D
	_assert_true(body_sprite != null, "body view contains BodySprite")

	actor_view.apply_view_state({
		"entity_id": 1,
		"player_slot": 0,
		"alive": true,
		"facing": 1,
		"position": Vector2.ZERO,
		"move_state": 1,
		"input_move_x": 0,
		"input_move_y": 1,
	})

	_assert_true(body_sprite != null and body_sprite.sprite_frames != null, "BodySprite binds SpriteFrames")
	if body_sprite != null:
		_assert_true(String(body_sprite.animation) == "run_down", "BodySprite plays run_down for down input")

	actor_view.free()


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		print("[PASS] %s" % message)
		return
	push_error("[FAIL] %s" % message)
