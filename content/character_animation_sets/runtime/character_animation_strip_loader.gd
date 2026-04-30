class_name CharacterAnimationStripLoader
extends RefCounted

const CharacterAnimationSetDefScript = preload("res://content/character_animation_sets/defs/character_animation_set_def.gd")
const AssetPathResolverScript = preload("res://content/assets/runtime/asset_path_resolver.gd")

const DIRECTIONS := ["down", "left", "right", "up"]
const MANIFEST_PATH := "res://content/character_animation_sets/data/runtime_strips/character_animation_strip_sets.json"
const DEFAULT_FRAME_WIDTH := 100
const DEFAULT_FRAME_HEIGHT := 100
const DEFAULT_FRAME_COUNT := 6
const DEFAULT_RUN_FPS := 8.0
const DEFAULT_PIVOT := Vector2(50, 100)
const DEFAULT_PIVOT_ADJUST := Vector2(0, -15)

static var _manifest_loaded := false
static var _entries_by_id: Dictionary = {}


static func can_load(animation_set_id: String) -> bool:
	var entry := _get_manifest_entry(animation_set_id)
	if entry.is_empty():
		return false
	var strips := _get_strips(entry)
	return _strip_exists(strips, "run_down")


static func load_animation_set(animation_set_id: String) -> CharacterAnimationSetDef:
	var entry := _get_manifest_entry(animation_set_id)
	if entry.is_empty():
		return null
	var sprite_frames := _build_sprite_frames(entry)
	if sprite_frames == null:
		return null
	var def := CharacterAnimationSetDefScript.new()
	def.animation_set_id = animation_set_id
	def.display_name = String(entry.get("display_name", animation_set_id))
	def.sprite_frames = sprite_frames
	def.frame_width = int(entry.get("frame_width", DEFAULT_FRAME_WIDTH))
	def.frame_height = int(entry.get("frame_height", DEFAULT_FRAME_HEIGHT))
	def.frames_per_direction = int(entry.get("frames_per_direction", DEFAULT_FRAME_COUNT))
	def.run_fps = float(entry.get("run_fps", DEFAULT_RUN_FPS))
	def.idle_frame_index = int(entry.get("idle_frame_index", 0))
	def.pivot_origin = _read_vector2(entry.get("pivot_origin", {}), DEFAULT_PIVOT)
	def.pivot_adjust = _read_vector2(entry.get("pivot_adjust", {}), DEFAULT_PIVOT_ADJUST)
	def.pivot = Vector2.ZERO
	def.loop_run = bool(entry.get("loop_run", true))
	def.loop_idle = bool(entry.get("loop_idle", false))
	def.content_hash = String(entry.get("content_hash", "runtime_strip_%s_v1" % animation_set_id))
	return def


static func _get_manifest_entry(animation_set_id: String) -> Dictionary:
	_ensure_manifest_loaded()
	if not _entries_by_id.has(animation_set_id):
		return {}
	return _entries_by_id[animation_set_id] as Dictionary


static func _ensure_manifest_loaded() -> void:
	if _manifest_loaded:
		return
	_manifest_loaded = true
	_entries_by_id.clear()
	if not FileAccess.file_exists(MANIFEST_PATH):
		push_error("CharacterAnimationStripLoader manifest missing: %s" % MANIFEST_PATH)
		return
	var file := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if file == null:
		push_error("CharacterAnimationStripLoader failed to open manifest: %s" % MANIFEST_PATH)
		return
	var text := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if not parsed is Dictionary:
		push_error("CharacterAnimationStripLoader invalid manifest json: %s" % MANIFEST_PATH)
		return
	var entries = (parsed as Dictionary).get("entries", [])
	if not entries is Array:
		push_error("CharacterAnimationStripLoader manifest entries must be an array: %s" % MANIFEST_PATH)
		return
	for entry in entries:
		if not entry is Dictionary:
			continue
		var entry_dict := entry as Dictionary
		var animation_set_id := String(entry_dict.get("animation_set_id", ""))
		if animation_set_id.is_empty():
			continue
		_entries_by_id[animation_set_id] = entry_dict


static func _get_strips(entry: Dictionary) -> Dictionary:
	var strips = entry.get("strips", {})
	return strips if strips is Dictionary else {}


static func _strip_exists(strips: Dictionary, strip_name: String) -> bool:
	var path := String(strips.get(strip_name, ""))
	return not path.is_empty() and AssetPathResolverScript.file_exists(path)


static func _read_vector2(value, default_value: Vector2) -> Vector2:
	if not value is Dictionary:
		return default_value
	var dict := value as Dictionary
	return Vector2(float(dict.get("x", default_value.x)), float(dict.get("y", default_value.y)))


static func _build_sprite_frames(entry: Dictionary) -> SpriteFrames:
	var strips := _get_strips(entry)
	var frame_width := int(entry.get("frame_width", DEFAULT_FRAME_WIDTH))
	var frame_height := int(entry.get("frame_height", DEFAULT_FRAME_HEIGHT))
	var fps := float(entry.get("run_fps", DEFAULT_RUN_FPS))
	var loop_run := bool(entry.get("loop_run", true))
	var loop_idle := bool(entry.get("loop_idle", false))
	var frames := SpriteFrames.new()
	for direction in DIRECTIONS:
		var run_textures := _load_strip(String(strips.get("run_%s" % direction, "")), frame_width, frame_height)
		if not run_textures.is_empty():
			_add_animation(frames, "run_%s" % direction, run_textures, fps, loop_run)
		var idle_textures := _load_strip(String(strips.get("idle_%s" % direction, "")), frame_width, frame_height)
		if not idle_textures.is_empty():
			_add_animation(frames, "idle_%s" % direction, idle_textures, fps, loop_idle)
	for pose in ["wait", "trigger", "dead", "defeat", "win"]:
		var textures := _load_strip(String(strips.get("%s_down" % pose, "")), frame_width, frame_height)
		if textures.is_empty():
			continue
		_add_animation(frames, "%s_down" % pose, textures, fps, true)
	return frames


static func _load_strip(path: String, frame_width: int, frame_height: int) -> Array[Texture2D]:
	var result: Array[Texture2D] = []
	var resolved_path := AssetPathResolverScript.resolve_path(path)
	if resolved_path.is_empty() or not FileAccess.file_exists(resolved_path):
		return result
	var image := Image.load_from_file(resolved_path)
	if image == null or image.is_empty():
		return result
	if image.get_width() % frame_width != 0 or image.get_height() != frame_height:
		push_error("CharacterAnimationStripLoader invalid strip size: %s" % resolved_path)
		return []
	var frame_count := int(image.get_width() / frame_width)
	for frame_index in range(frame_count):
		var frame_image := image.get_region(Rect2i(frame_index * frame_width, 0, frame_width, frame_height))
		result.append(ImageTexture.create_from_image(frame_image))
	return result


static func _add_animation(sprite_frames: SpriteFrames, animation_name: String, textures: Array[Texture2D], fps: float, loop: bool) -> void:
	if sprite_frames.has_animation(animation_name):
		sprite_frames.clear(animation_name)
	else:
		sprite_frames.add_animation(animation_name)
	sprite_frames.set_animation_speed(animation_name, fps)
	sprite_frames.set_animation_loop(animation_name, loop)
	for texture in textures:
		sprite_frames.add_frame(animation_name, texture)
