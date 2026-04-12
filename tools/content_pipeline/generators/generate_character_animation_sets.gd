extends ContentCsvGeneratorBase
class_name GenerateCharacterAnimationSets

const CharacterAnimationSetDefScript = preload("res://content/character_animation_sets/defs/character_animation_set_def.gd")

const INPUT_CSV_PATH := "res://content_source/csv/character_animation_sets/character_animation_sets.csv"
const OUTPUT_DEF_DIR := "res://content/character_animation_sets/data/sets/"
const OUTPUT_FRAMES_DIR := "res://content/character_animation_sets/generated/sprite_frames/"
const DIRECTION_KEYS := ["down", "left", "right", "up"]
const EXTRA_POSE_KEYS := ["trapped", "victory", "defeat"]
const EXTRA_POSE_DIRECTION := "down"
const EXTRA_POSE_LOOP := {
	"trapped": true,
	"victory": true,
	"defeat": true,
}


func generate() -> void:
	var lines := load_csv_lines(INPUT_CSV_PATH)
	if lines.size() <= 1:
		push_error("character_animation_sets.csv has no data rows")
		return

	var header := split_csv_line(lines[0])
	var header_index := build_header_index(header)
	var seen_animation_set_ids: Dictionary = {}

	for i in range(1, lines.size()):
		var row := split_csv_line(lines[i])
		var animation_set_id := get_cell(row, header_index, "animation_set_id")
		if animation_set_id.is_empty():
			push_error("character_animation_sets.csv animation_set_id is empty")
			continue
		if seen_animation_set_ids.has(animation_set_id):
			push_error("character_animation_sets.csv duplicate animation_set_id: %s" % animation_set_id)
			continue
		seen_animation_set_ids[animation_set_id] = true
		_generate_row(row, header_index)


func _generate_row(row: PackedStringArray, header_index: Dictionary) -> void:
	var animation_set_id := get_cell(row, header_index, "animation_set_id")
	if animation_set_id.is_empty():
		push_error("character_animation_sets.csv animation_set_id is empty")
		return

	var frame_width := get_cell(row, header_index, "frame_width").to_int()
	var frame_height := get_cell(row, header_index, "frame_height").to_int()
	var frames_per_direction := get_cell(row, header_index, "frames_per_direction").to_int()
	if frame_width <= 0 or frame_height <= 0:
		push_error("CharacterAnimationSet %s invalid frame size: %dx%d" % [animation_set_id, frame_width, frame_height])
		return
	if frames_per_direction <= 0:
		push_error("CharacterAnimationSet %s invalid frames_per_direction: %d" % [animation_set_id, frames_per_direction])
		return

	var images_by_direction := _load_direction_images(animation_set_id, row, header_index)
	if images_by_direction.is_empty():
		return

	var frames_by_direction: Dictionary = {}
	for direction in DIRECTION_KEYS:
		var image := images_by_direction[direction] as Image
		if not _validate_strip(animation_set_id, direction, image, frame_width, frame_height, frames_per_direction):
			return
		frames_by_direction[direction] = _slice_strip(image, frame_width, frame_height, frames_per_direction)

	var extra_frames_by_animation := _load_extra_pose_frames(
		animation_set_id,
		row,
		header_index,
		frame_width,
		frame_height,
		frames_per_direction
	)

	var sprite_frames := SpriteFrames.new()
	var run_fps := get_cell(row, header_index, "run_fps").to_float()
	if run_fps <= 0.0:
		push_error("CharacterAnimationSet %s invalid run_fps: %s" % [animation_set_id, str(run_fps)])
		return
	var idle_frame_index := clampi(get_cell(row, header_index, "idle_frame_index").to_int(), 0, frames_per_direction - 1)
	var loop_run := _parse_bool(get_cell(row, header_index, "loop_run"))
	var loop_idle := _parse_bool(get_cell(row, header_index, "loop_idle"))

	for direction in DIRECTION_KEYS:
		var direction_frames: Array[Texture2D] = frames_by_direction[direction]
		_add_animation(sprite_frames, "run_%s" % direction, direction_frames, run_fps, loop_run)
		var idle_frame: Array[Texture2D] = [direction_frames[idle_frame_index]]
		_add_animation(sprite_frames, "idle_%s" % direction, idle_frame, run_fps, loop_idle)
		_add_animation(sprite_frames, "dead_%s" % direction, idle_frame, run_fps, false)

	for animation_name in extra_frames_by_animation.keys():
		var pose_name := String(animation_name).split("_")[0]
		var loop_extra := bool(EXTRA_POSE_LOOP.get(pose_name, false))
		_add_animation(sprite_frames, String(animation_name), extra_frames_by_animation[animation_name], run_fps, loop_extra)

	var frames_output_path := OUTPUT_FRAMES_DIR + animation_set_id + "_frames.tres"
	if not save_resource(sprite_frames, frames_output_path):
		return

	var def := CharacterAnimationSetDefScript.new()
	def.animation_set_id = animation_set_id
	def.display_name = get_cell(row, header_index, "display_name")
	def.sprite_frames = load(frames_output_path) as SpriteFrames
	def.frame_width = frame_width
	def.frame_height = frame_height
	def.frames_per_direction = frames_per_direction
	def.run_fps = run_fps
	def.idle_frame_index = idle_frame_index
	def.pivot_origin = Vector2(
		get_cell(row, header_index, "pivot_x").to_float(),
		get_cell(row, header_index, "pivot_y").to_float()
	)
	def.pivot_adjust = Vector2(
		get_cell(row, header_index, "pivot_adjust_x").to_float(),
		get_cell(row, header_index, "pivot_adjust_y").to_float()
	)
	def.pivot = Vector2.ZERO
	def.loop_run = loop_run
	def.loop_idle = loop_idle
	def.content_hash = get_cell(row, header_index, "content_hash")

	var def_output_path := OUTPUT_DEF_DIR + animation_set_id + ".tres"
	save_resource(def, def_output_path)


func _load_direction_images(animation_set_id: String, row: PackedStringArray, header_index: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for direction in DIRECTION_KEYS:
		var strip_path := get_cell(row, header_index, "%s_strip_path" % direction)
		if strip_path.is_empty():
			push_error("CharacterAnimationSet %s missing %s strip path" % [animation_set_id, direction])
			return {}
		if not _source_image_exists(strip_path):
			push_error("CharacterAnimationSet %s missing strip resource: %s" % [animation_set_id, strip_path])
			return {}
		var image := Image.load_from_file(ProjectSettings.globalize_path(strip_path))
		if image == null or image.is_empty():
			push_error("CharacterAnimationSet %s failed to load strip image: %s" % [animation_set_id, strip_path])
			return {}
		result[direction] = image
	return result


func _load_extra_pose_frames(
	animation_set_id: String,
	row: PackedStringArray,
	header_index: Dictionary,
	frame_width: int,
	frame_height: int,
	frames_per_direction: int
) -> Dictionary:
	var result: Dictionary = {}
	for pose in EXTRA_POSE_KEYS:
		var column_name := "%s_%s_strip_path" % [pose, EXTRA_POSE_DIRECTION]
		var strip_path := get_cell(row, header_index, column_name)
		if strip_path.is_empty():
			continue
		if not _source_image_exists(strip_path):
			push_error("CharacterAnimationSet %s missing extra strip resource: %s" % [animation_set_id, strip_path])
			return {}
		var image := Image.load_from_file(ProjectSettings.globalize_path(strip_path))
		if image == null or image.is_empty():
			push_error("CharacterAnimationSet %s failed to load extra strip image: %s" % [animation_set_id, strip_path])
			return {}
		var animation_name := "%s_%s" % [pose, EXTRA_POSE_DIRECTION]
		if not _validate_strip(animation_set_id, animation_name, image, frame_width, frame_height, frames_per_direction):
			return {}
		result[animation_name] = _slice_strip(image, frame_width, frame_height, frames_per_direction)
	return result


func _validate_strip(
	animation_set_id: String,
	direction: String,
	image: Image,
	frame_width: int,
	frame_height: int,
	frames_per_direction: int
) -> bool:
	if image.get_width() % frame_width != 0 or image.get_height() % frame_height != 0:
		push_error(
			"CharacterAnimationSet %s %s strip size %dx%d is not divisible by frame size %dx%d"
			% [animation_set_id, direction, image.get_width(), image.get_height(), frame_width, frame_height]
		)
		return false
	if image.get_height() != frame_height:
		push_error(
			"CharacterAnimationSet %s %s strip height %d does not match frame_height %d"
			% [animation_set_id, direction, image.get_height(), frame_height]
		)
		return false
	var actual_frame_count := image.get_width() / frame_width
	if actual_frame_count != frames_per_direction:
		push_error(
			"CharacterAnimationSet %s %s strip frame count %d does not match expected %d"
			% [animation_set_id, direction, actual_frame_count, frames_per_direction]
		)
		return false
	return true


func _slice_strip(image: Image, frame_width: int, frame_height: int, frames_per_direction: int) -> Array[Texture2D]:
	var frames: Array[Texture2D] = []
	for frame_index in range(frames_per_direction):
		var frame_image := image.get_region(Rect2i(frame_index * frame_width, 0, frame_width, frame_height))
		frames.append(ImageTexture.create_from_image(frame_image))
	return frames


func _source_image_exists(resource_path: String) -> bool:
	return FileAccess.file_exists(ProjectSettings.globalize_path(resource_path))


func _add_animation(
	sprite_frames: SpriteFrames,
	animation_name: String,
	frames: Array[Texture2D],
	fps: float,
	loop_enabled: bool
) -> void:
	sprite_frames.add_animation(animation_name)
	sprite_frames.set_animation_speed(animation_name, fps)
	sprite_frames.set_animation_loop(animation_name, loop_enabled)
	for frame in frames:
		sprite_frames.add_frame(animation_name, frame)


func _parse_bool(value: String) -> bool:
	return value.strip_edges().to_lower() == "true"
