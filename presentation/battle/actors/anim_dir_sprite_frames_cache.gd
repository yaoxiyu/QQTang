class_name AnimDirSpriteFramesCache
extends RefCounted

static var _cache: Dictionary = {}


static func load_frames(
	anim_dir: String,
	anim_name: String = "stand",
	fps: float = 10.0,
	loop: bool = true
) -> SpriteFrames:
	var cache_key := "%s|%s|%s|%s" % [anim_dir, anim_name, str(fps), str(loop)]
	if _cache.has(cache_key):
		return _cache[cache_key] as SpriteFrames

	var dir := DirAccess.open(anim_dir)
	if dir == null:
		_cache[cache_key] = null
		return null

	var frame_files: Array[String] = []
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while not file_name.is_empty():
		if file_name.ends_with(".png") and not file_name.ends_with(".png.import"):
			frame_files.append(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()

	if frame_files.is_empty():
		_cache[cache_key] = null
		return null

	frame_files.sort()
	var sprite_frames := SpriteFrames.new()
	sprite_frames.add_animation(anim_name)
	sprite_frames.set_animation_speed(anim_name, fps)
	sprite_frames.set_animation_loop(anim_name, loop)

	for frame_file in frame_files:
		var texture := load(anim_dir + "/" + frame_file) as Texture2D
		if texture != null:
			sprite_frames.add_frame(anim_name, texture)

	if sprite_frames.get_frame_count(anim_name) <= 0:
		_cache[cache_key] = null
		return null

	_cache[cache_key] = sprite_frames
	return sprite_frames

