extends ContentCsvGeneratorBase
class_name GenerateVfxAnimationSets

const VfxAnimationSetDefScript = preload("res://content/vfx_animation_sets/defs/vfx_animation_set_def.gd")

const INPUT_CSV_PATH := "res://content_source/csv/vfx_animation_sets/vfx_animation_sets.csv"
const OUTPUT_DEF_DIR := "res://content/vfx_animation_sets/data/sets/"
const OUTPUT_FRAMES_DIR := "res://content/vfx_animation_sets/generated/sprite_frames/"


func generate() -> void:
	var lines := load_csv_lines(INPUT_CSV_PATH)
	if lines.size() <= 1:
		return
	var header := split_csv_line(lines[0])
	var header_index := build_header_index(header)
	var seen_ids: Dictionary = {}
	for i in range(1, lines.size()):
		var row := split_csv_line(lines[i])
		var vfx_set_id := get_cell(row, header_index, "vfx_set_id")
		if vfx_set_id.is_empty():
			push_error("vfx_animation_sets.csv vfx_set_id is empty")
			continue
		if seen_ids.has(vfx_set_id):
			push_error("vfx_animation_sets.csv duplicate vfx_set_id: %s" % vfx_set_id)
			continue
		seen_ids[vfx_set_id] = true
		_generate_row(row, header_index)


func _generate_row(row: PackedStringArray, header_index: Dictionary) -> void:
	var vfx_set_id := get_cell(row, header_index, "vfx_set_id")
	var frame_width := get_cell(row, header_index, "frame_width").to_int()
	var frame_height := get_cell(row, header_index, "frame_height").to_int()
	if frame_width <= 0 or frame_height <= 0:
		push_error("VfxAnimationSet %s invalid frame size" % vfx_set_id)
		return
	var sprite_frames := SpriteFrames.new()
	var enter_frames := _load_strip(sprite_frames, "enter", get_cell(row, header_index, "enter_strip_path"), frame_width, frame_height, get_cell(row, header_index, "enter_frames").to_int(), get_cell(row, header_index, "enter_fps").to_float(), false)
	var loop_frames := _load_strip(sprite_frames, "loop", get_cell(row, header_index, "loop_strip_path"), frame_width, frame_height, get_cell(row, header_index, "loop_frames").to_int(), get_cell(row, header_index, "loop_fps").to_float(), true)
	var release_frames := _load_strip(sprite_frames, "release", get_cell(row, header_index, "release_strip_path"), frame_width, frame_height, get_cell(row, header_index, "release_frames").to_int(), get_cell(row, header_index, "release_fps").to_float(), false)
	if enter_frames <= 0 or loop_frames <= 0 or release_frames <= 0:
		return
	var frames_output_path := OUTPUT_FRAMES_DIR + vfx_set_id + "_frames.tres"
	if not save_resource(sprite_frames, frames_output_path):
		return
	var def := VfxAnimationSetDefScript.new()
	def.vfx_set_id = vfx_set_id
	def.display_name = get_cell(row, header_index, "display_name")
	def.sprite_frames = load(frames_output_path) as SpriteFrames
	def.frame_width = frame_width
	def.frame_height = frame_height
	def.enter_frames = enter_frames
	def.loop_frames = loop_frames
	def.release_frames = release_frames
	def.enter_fps = get_cell(row, header_index, "enter_fps").to_float()
	def.loop_fps = get_cell(row, header_index, "loop_fps").to_float()
	def.release_fps = get_cell(row, header_index, "release_fps").to_float()
	def.pivot = Vector2(get_cell(row, header_index, "pivot_x").to_float(), get_cell(row, header_index, "pivot_y").to_float())
	def.layer = get_cell(row, header_index, "layer")
	def.follow_actor = get_cell(row, header_index, "follow_actor").to_lower() == "true"
	def.content_hash = get_cell(row, header_index, "content_hash")
	save_resource(def, OUTPUT_DEF_DIR + vfx_set_id + ".tres")


func _load_strip(sprite_frames: SpriteFrames, animation_name: String, strip_path: String, frame_width: int, frame_height: int, expected_frames: int, fps: float, loop_enabled: bool) -> int:
	if strip_path.is_empty() or expected_frames <= 0:
		push_error("VfxAnimationSet missing %s strip" % animation_name)
		return 0
	if not FileAccess.file_exists(ProjectSettings.globalize_path(strip_path)):
		push_error("VfxAnimationSet missing strip resource: %s" % strip_path)
		return 0
	var image := Image.load_from_file(ProjectSettings.globalize_path(strip_path))
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
