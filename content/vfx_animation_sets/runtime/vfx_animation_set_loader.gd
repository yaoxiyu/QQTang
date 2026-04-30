class_name VfxAnimationSetLoader
extends RefCounted

const VfxAnimationSetCatalogScript = preload("res://content/vfx_animation_sets/catalog/vfx_animation_set_catalog.gd")
const AssetPathResolverScript = preload("res://content/assets/runtime/asset_path_resolver.gd")

static var _runtime_cache: Dictionary = {}


static func load_vfx_set(vfx_set_id: String) -> Resource:
	if vfx_set_id.is_empty():
		return null
	if _runtime_cache.has(vfx_set_id):
		return _runtime_cache[vfx_set_id] as Resource
	var vfx_set := VfxAnimationSetCatalogScript.get_by_id(vfx_set_id)
	if vfx_set == null:
		push_error("VfxAnimationSetLoader.load_vfx_set failed: missing VfxAnimationSetDef for %s" % vfx_set_id)
		return null
	if vfx_set.sprite_frames == null:
		vfx_set.sprite_frames = _build_sprite_frames(vfx_set)
	if vfx_set.sprite_frames == null:
		push_error("VfxAnimationSetLoader.load_vfx_set failed: missing SpriteFrames for %s" % vfx_set_id)
		return null
	_runtime_cache[vfx_set_id] = vfx_set
	return vfx_set


static func _build_sprite_frames(vfx_set: Resource) -> SpriteFrames:
	var sprite_frames := SpriteFrames.new()
	var enter_count := _load_strip(
		sprite_frames,
		"enter",
		String(vfx_set.enter_strip_path),
		int(vfx_set.frame_width),
		int(vfx_set.frame_height),
		int(vfx_set.enter_frames),
		float(vfx_set.enter_fps),
		false
	)
	var loop_count := _load_strip(
		sprite_frames,
		"loop",
		String(vfx_set.loop_strip_path),
		int(vfx_set.frame_width),
		int(vfx_set.frame_height),
		int(vfx_set.loop_frames),
		float(vfx_set.loop_fps),
		true
	)
	var release_count := _load_strip(
		sprite_frames,
		"release",
		String(vfx_set.release_strip_path),
		int(vfx_set.frame_width),
		int(vfx_set.frame_height),
		int(vfx_set.release_frames),
		float(vfx_set.release_fps),
		false
	)
	if enter_count <= 0 or loop_count <= 0 or release_count <= 0:
		return null
	return sprite_frames


static func _load_strip(
	sprite_frames: SpriteFrames,
	animation_name: String,
	strip_path: String,
	frame_width: int,
	frame_height: int,
	expected_frames: int,
	fps: float,
	loop_enabled: bool
) -> int:
	if strip_path.is_empty() or expected_frames <= 0:
		push_error("VfxAnimationSet missing %s strip" % animation_name)
		return 0
	var resolved_path := AssetPathResolverScript.resolve_path(strip_path)
	if resolved_path.is_empty() or not FileAccess.file_exists(resolved_path):
		push_error("VfxAnimationSet missing strip resource: %s" % strip_path)
		return 0
	var image := Image.load_from_file(resolved_path)
	if image == null or image.is_empty():
		push_error("VfxAnimationSet failed to load strip image: %s" % strip_path)
		return 0
	if image.get_width() != frame_width * expected_frames or image.get_height() != frame_height:
		push_error("VfxAnimationSet %s strip size %dx%d expected %dx%d" % [animation_name, image.get_width(), image.get_height(), frame_width * expected_frames, frame_height])
		return 0
	sprite_frames.add_animation(animation_name)
	sprite_frames.set_animation_speed(animation_name, fps)
	sprite_frames.set_animation_loop(animation_name, loop_enabled)
	for frame_index in range(expected_frames):
		var frame_image := image.get_region(Rect2i(frame_index * frame_width, 0, frame_width, frame_height))
		sprite_frames.add_frame(animation_name, ImageTexture.create_from_image(frame_image))
	return expected_frames
