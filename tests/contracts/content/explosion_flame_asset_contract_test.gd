extends "res://tests/gut/base/qqt_gut_test.gd"

const BattleExplosionActorViewScript = preload("res://presentation/battle/actors/explosion_actor_view.gd")

const MANIFEST_PATH := "res://external/assets/derived/assets/animation/explosions/normal/explosion_normal_segments.json"
const SEGMENTS_DIR := "res://external/assets/derived/assets/animation/explosions/normal/segments/"


func test_explosion_flame_assets_load_and_bind() -> void:
	var manifest := _load_manifest()
	assert_false(manifest.is_empty(), "explosion flame manifest should load")

	var segment_mapping: Dictionary = manifest.get("segment_mapping", {})
	assert_eq(segment_mapping.size(), 10, "flame manifest should expose 10 runtime segments")
	_assert_segment_frames_load(segment_mapping)
	_assert_type1_view_builds_cross_segments()
	_assert_type2_view_uses_flame10_for_each_cell()


func _load_manifest() -> Dictionary:
	var file := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Dictionary:
		return parsed as Dictionary
	return {}


func _assert_segment_frames_load(segment_mapping: Dictionary) -> void:
	for segment_name in segment_mapping.keys():
		var segment: Dictionary = segment_mapping[segment_name]
		var expected_frames := int(segment.get("frames", 0))
		assert_gt(expected_frames, 0, "%s should declare frame count" % segment_name)
		for i in range(expected_frames):
			var frame_path := "%s%s_%02d.png" % [SEGMENTS_DIR, segment_name, i]
			var texture := load(frame_path) as Texture2D
			assert_not_null(texture, "%s should load" % frame_path)


func _assert_type1_view_builds_cross_segments() -> void:
	var view: BattleExplosionActorView = BattleExplosionActorViewScript.new()
	add_child(view)
	view.configure(
		[Vector2i(3, 3), Vector2i(4, 3), Vector2i(5, 3), Vector2i(3, 2), Vector2i(3, 1)],
		40.0,
		"bubble_style_bomb11",
		Color.WHITE
	)
	assert_eq(view.get_child_count(), 5, "type1 cross explosion should create one animated node per covered cell")
	for child in view.get_children():
		assert_true(child is AnimatedSprite2D, "type1 flame child should be AnimatedSprite2D")
	view.free()


func _assert_type2_view_uses_flame10_for_each_cell() -> void:
	var view: BattleExplosionActorView = BattleExplosionActorViewScript.new()
	add_child(view)
	view.configure(
		[Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 2), Vector2i(2, 2)],
		40.0,
		"bubble_style_bomb13",
		Color.WHITE
	)
	assert_eq(view.get_child_count(), 4, "type2 explosion should create one animated node per covered cell")
	for child in view.get_children():
		assert_true(child is AnimatedSprite2D, "type2 flame child should be AnimatedSprite2D")
		if child is AnimatedSprite2D:
			var animated := child as AnimatedSprite2D
			assert_not_null(animated.sprite_frames, "type2 flame should have SpriteFrames")
			assert_eq(animated.sprite_frames.get_frame_count("default"), 9, "type2 flame should use flame10 9-frame animation")
	view.free()
