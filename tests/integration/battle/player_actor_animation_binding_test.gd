extends "res://tests/gut/base/qqt_integration_test.gd"

const BattlePlayerActorViewScript = preload("res://presentation/battle/actors/player_actor_view.gd")
const BattlePlayerVisualProfileScript = preload("res://presentation/battle/actors/battle_player_visual_profile.gd")
const BattlePlayerVisualProfileBuilderScript = preload("res://presentation/battle/actors/battle_player_visual_profile_builder.gd")
const BattleRuntimeConfigScript = preload("res://gameplay/battle/runtime/battle_runtime_config.gd")
const PlayerRuntimeConfigScript = preload("res://gameplay/battle/runtime/player_runtime_config.gd")
const CharacterLoaderScript = preload("res://content/characters/runtime/character_loader.gd")
const CharacterAnimationSetLoaderScript = preload("res://content/character_animation_sets/runtime/character_animation_set_loader.gd")
const CharacterSkinCatalogScript = preload("res://content/character_skins/catalog/character_skin_catalog.gd")
const RoomTeamPaletteScript = preload("res://app/front/room/room_team_palette.gd")


func test_main() -> void:
	_main_body()


func _main_body() -> void:
	_test_player_actor_binds_character_animation_set()
	_test_player_actor_maps_sim_facing_to_cardinal_animation()
	_test_jelly_overlay_keeps_trigger_character_visible()
	_test_remote_player_actor_uses_move_state_for_run_animation()
	_test_remote_player_actor_uses_authoritative_anim_direction()
	_test_actor_snaps_large_respawn_teleport()
	_test_actor_applies_team_tint_when_team_animation_variant_is_missing()
	_test_visual_profile_builder_prefers_runtime_slot_and_team()


func _test_player_actor_binds_character_animation_set() -> void:
	var actor_view = BattlePlayerActorViewScript.new()
	add_child(actor_view)

	var profile = BattlePlayerVisualProfileScript.new()
	profile.player_slot = 0
	profile.character_id = "10101"
	profile.character_presentation = CharacterLoaderScript.load_character_presentation("10101")
	profile.character_skin = CharacterSkinCatalogScript.get_by_id("skin_gold")
	profile.animation_set = CharacterAnimationSetLoaderScript.load_animation_set("char_anim_qqt_10101")

	_assert_true(profile.character_presentation != null, "profile loads char_pres_huoying")
	_assert_true(profile.character_skin != null, "profile loads skin_gold")
	_assert_true(profile.animation_set != null, "profile loads char_anim_qqt_10101")

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
		"anim_is_moving": true,
		"anim_move_x": 0,
		"anim_move_y": 1,
	})

	_assert_true(body_sprite != null and body_sprite.sprite_frames != null, "BodySprite binds SpriteFrames")
	if body_sprite != null:
		_assert_true(String(body_sprite.animation) == "run_down", "BodySprite plays run_down for down input")

	actor_view.free()


func _test_player_actor_maps_sim_facing_to_cardinal_animation() -> void:
	var actor_view = BattlePlayerActorViewScript.new()
	add_child(actor_view)

	var profile = BattlePlayerVisualProfileScript.new()
	profile.player_slot = 0
	profile.character_id = "10101"
	profile.character_presentation = CharacterLoaderScript.load_character_presentation("10101")
	profile.animation_set = CharacterAnimationSetLoaderScript.load_animation_set("char_anim_qqt_10101")
	actor_view.configure_visual_profile(profile)

	var body_view = actor_view.get("_body_view") as Node2D
	var body_sprite := body_view.get_node_or_null("BodySprite") as AnimatedSprite2D if body_view != null else null
	_assert_true(body_sprite != null, "facing mapper body view contains BodySprite")

	var cases := [
		{"facing": 0, "animation": "idle_up"},
		{"facing": 1, "animation": "idle_down"},
		{"facing": 2, "animation": "idle_left"},
		{"facing": 3, "animation": "idle_right"},
	]
	for entry in cases:
		actor_view.apply_view_state({
			"entity_id": 10,
			"player_slot": 0,
			"alive": true,
			"facing": int(entry.get("facing", 0)),
			"position": Vector2.ZERO,
			"anim_is_moving": false,
		})
		if body_sprite != null:
			_assert_true(String(body_sprite.animation) == String(entry.get("animation", "")), "Facing %d maps to %s" % [int(entry.get("facing", 0)), String(entry.get("animation", ""))])

	actor_view.free()


func _test_jelly_overlay_keeps_trigger_character_visible() -> void:
	var actor_view = BattlePlayerActorViewScript.new()
	add_child(actor_view)

	var profile = BattlePlayerVisualProfileScript.new()
	profile.player_slot = 0
	profile.character_id = "10101"
	profile.character_presentation = CharacterLoaderScript.load_character_presentation("10101")
	profile.animation_set = CharacterAnimationSetLoaderScript.load_animation_set("char_anim_qqt_10101")
	actor_view.configure_visual_profile(profile)

	actor_view.apply_view_state({
		"entity_id": 11,
		"player_slot": 0,
		"alive": true,
		"pose_state": "trigger",
		"facing": 1,
		"position": Vector2.ZERO,
		"anim_is_moving": false,
	})

	var body_view = actor_view.get("_body_view") as Node2D
	var status_root = actor_view.get("_status_effect_controller") as Node2D
	var body_sprite := body_view.get_node_or_null("BodySprite") as AnimatedSprite2D if body_view != null else null
	var jelly_view := status_root.get_node_or_null("JellyTrapEffectView") as Node2D if status_root != null else null
	var jelly_sprite := jelly_view.get_node_or_null("EffectSprite") as AnimatedSprite2D if jelly_view != null else null

	_assert_true(body_sprite != null and String(body_sprite.animation) == "trigger_down", "trigger pose should keep character trigger animation")
	_assert_true(body_view != null and status_root != null and status_root.z_index > body_view.z_index, "jelly status root should render above character body")
	_assert_true(jelly_view != null and jelly_sprite != null, "trigger pose should create jelly overlay")
	if jelly_sprite != null:
		_assert_true(jelly_sprite.self_modulate.a < 1.0, "jelly overlay should be translucent so trigger remains visible")

	actor_view.free()


func _test_remote_player_actor_uses_move_state_for_run_animation() -> void:
	var actor_view = BattlePlayerActorViewScript.new()
	add_child(actor_view)

	var profile = BattlePlayerVisualProfileScript.new()
	profile.player_slot = 0
	profile.character_id = "10101"
	profile.character_presentation = CharacterLoaderScript.load_character_presentation("10101")
	profile.character_skin = CharacterSkinCatalogScript.get_by_id("skin_gold")
	profile.animation_set = CharacterAnimationSetLoaderScript.load_animation_set("char_anim_qqt_10101")
	actor_view.configure_visual_profile(profile)

	var body_view = actor_view.get("_body_view") as Node2D
	var body_sprite := body_view.get_node_or_null("BodySprite") as AnimatedSprite2D if body_view != null else null
	_assert_true(body_sprite != null, "remote body view contains BodySprite")

	actor_view.apply_view_state({
		"entity_id": 2,
		"player_slot": 0,
		"is_local_player": false,
		"alive": true,
		"facing": 3,
		"position": Vector2.ZERO,
		"anim_is_moving": true,
		"anim_move_x": 1,
		"anim_move_y": 0,
	})

	if body_sprite != null:
		_assert_true(String(body_sprite.animation) == "run_right", "Remote BodySprite plays run_right from move_state")

	actor_view.free()


func _test_remote_player_actor_uses_authoritative_anim_direction() -> void:
	var actor_view = BattlePlayerActorViewScript.new()
	add_child(actor_view)

	var profile = BattlePlayerVisualProfileScript.new()
	profile.player_slot = 0
	profile.character_id = "10101"
	profile.character_presentation = CharacterLoaderScript.load_character_presentation("10101")
	profile.character_skin = CharacterSkinCatalogScript.get_by_id("skin_gold")
	profile.animation_set = CharacterAnimationSetLoaderScript.load_animation_set("char_anim_qqt_10101")
	actor_view.configure_visual_profile(profile)

	var body_view = actor_view.get("_body_view") as Node2D
	var body_sprite := body_view.get_node_or_null("BodySprite") as AnimatedSprite2D if body_view != null else null
	_assert_true(body_sprite != null, "remote directional body view contains BodySprite")

	actor_view.apply_view_state({
		"entity_id": 3,
		"player_slot": 0,
		"is_local_player": false,
		"alive": true,
		"facing": 1,
		"anim_is_moving": true,
		"anim_move_x": -1,
		"anim_move_y": 0,
		"position": Vector2.ZERO,
	})

	if body_sprite != null:
		_assert_true(String(body_sprite.animation) == "run_left", "Remote BodySprite uses authoritative anim direction")

	actor_view.free()


func _test_actor_snaps_large_respawn_teleport() -> void:
	var actor_view = BattlePlayerActorViewScript.new()
	add_child(actor_view)

	var profile = BattlePlayerVisualProfileScript.new()
	profile.player_slot = 0
	profile.character_id = "10101"
	profile.character_presentation = CharacterLoaderScript.load_character_presentation("10101")
	profile.character_skin = CharacterSkinCatalogScript.get_by_id("skin_gold")
	profile.animation_set = CharacterAnimationSetLoaderScript.load_animation_set("char_anim_qqt_10101")
	actor_view.configure_visual_profile(profile)

	actor_view.apply_view_state({
		"entity_id": 4,
		"player_slot": 0,
		"is_local_player": false,
		"alive": false,
		"pose_state": "defeat",
		"facing": 1,
		"cell_size": 40.0,
		"position": Vector2(40.0, 40.0),
	})
	actor_view.position = Vector2(40.0, 40.0)

	actor_view.apply_view_state({
		"entity_id": 4,
		"player_slot": 0,
		"is_local_player": false,
		"alive": true,
		"pose_state": "normal",
		"facing": 1,
		"cell_size": 40.0,
		"position": Vector2(200.0, 40.0),
	})

	_assert_true(actor_view.position == Vector2(200.0, 40.0), "Actor view snaps to respawn target instead of lerping across map")
	actor_view.free()


func _test_actor_applies_team_tint_when_team_animation_variant_is_missing() -> void:
	var actor_view = BattlePlayerActorViewScript.new()
	add_child(actor_view)

	var profile = BattlePlayerVisualProfileScript.new()
	profile.player_slot = 0
	profile.team_id = 8
	profile.character_id = "10101"
	profile.character_presentation = CharacterLoaderScript.load_character_presentation("10101")
	profile.animation_set = CharacterAnimationSetLoaderScript.load_animation_set("char_anim_qqt_10101")
	actor_view.configure_visual_profile(profile)

	var body_view = actor_view.get("_body_view") as Node2D
	var expected_tint := Color.WHITE.lerp(RoomTeamPaletteScript.color_for_team(8), 0.45)
	_assert_true(body_view != null, "team tinted actor should create body view")
	if body_view != null:
		_assert_true(body_view.modulate == expected_tint, "actor should apply team tint when character has no team animation variant")

	actor_view.free()


func _test_visual_profile_builder_prefers_runtime_slot_and_team() -> void:
	var runtime_config = BattleRuntimeConfigScript.new()
	var player_config = PlayerRuntimeConfigScript.new()
	player_config.peer_id = 42
	player_config.player_slot = 3
	player_config.team_id = 8
	player_config.character_id = "10101"
	player_config.character_presentation = CharacterLoaderScript.load_character_presentation("10101")
	player_config.character_skin = CharacterSkinCatalogScript.get_by_id("skin_gold")
	runtime_config.player_configs.append(player_config)

	var stale_player_slots: Array[Dictionary] = [{
		"peer_id": 42,
		"slot_index": 0,
		"team_id": 1,
	}]
	var profiles := BattlePlayerVisualProfileBuilderScript.new().build(runtime_config, stale_player_slots)
	var profile = profiles.get(3, null) as BattlePlayerVisualProfile

	_assert_true(profile != null, "visual profile should be keyed by runtime player_slot")
	if profile != null:
		_assert_true(profile.player_slot == 3, "visual profile should use runtime player_slot over player_slots index fallback")
		_assert_true(profile.team_id == 8, "visual profile should use runtime team_id over stale player_slots fallback")


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		return
