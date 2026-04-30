extends ContentCsvGeneratorBase
class_name GenerateBubbleAnimationSets

const BubbleAnimationSetDefScript = preload("res://content/bubble_animation_sets/defs/bubble_animation_set_def.gd")
const AssetPathResolverScript = preload("res://content/assets/runtime/asset_path_resolver.gd")

const INPUT_CSV_PATH := "res://content_source/csv/bubble_animation_sets/bubble_animation_sets.csv"
const OUTPUT_DEF_DIR := "res://content/bubble_animation_sets/data/sets/"
const OUTPUT_FRAMES_DIR := "res://content/bubble_animation_sets/generated/sprite_frames/"


func generate() -> void:
	var lines := load_csv_lines(INPUT_CSV_PATH)
	if lines.size() <= 1:
		push_error("bubble_animation_sets.csv has no data rows")
		return

	var header := split_csv_line(lines[0])
	var header_index := build_header_index(header)

	for i in range(1, lines.size()):
		var row := split_csv_line(lines[i])
		_generate_row(row, header_index)


func _generate_row(row: PackedStringArray, header_index: Dictionary) -> void:
	var animation_set_id := get_cell(row, header_index, "animation_set_id")
	if animation_set_id.is_empty():
		push_error("bubble_animation_sets.csv animation_set_id is empty")
		return

	var source_layout_type := get_cell(row, header_index, "source_layout_type").to_lower()
	var source_image_path := get_cell(row, header_index, "source_image_path")
	var frame_width := get_cell(row, header_index, "frame_width").to_int()
	var frame_height := get_cell(row, header_index, "frame_height").to_int()
	var frame_count := get_cell(row, header_index, "frame_count").to_int()
	var source_columns := get_cell(row, header_index, "source_columns").to_int()
	var source_rows := get_cell(row, header_index, "source_rows").to_int()
	var idle_fps := get_cell(row, header_index, "idle_fps").to_float()
	var idle_frame_index := get_cell(row, header_index, "idle_frame_index").to_int()
	var loop_idle := _parse_bool(get_cell(row, header_index, "loop_idle"))

	if source_layout_type != "grid" and source_layout_type != "strip":
		push_error("BubbleAnimationSet %s invalid source_layout_type: %s" % [animation_set_id, source_layout_type])
		return
	var resolved_source_image_path := AssetPathResolverScript.resolve_path(source_image_path)
	if source_image_path.is_empty() or resolved_source_image_path.is_empty() or not FileAccess.file_exists(resolved_source_image_path):
		push_error("BubbleAnimationSet %s missing source image: %s" % [animation_set_id, source_image_path])
		return
	if frame_width <= 0 or frame_height <= 0 or frame_count <= 0:
		push_error("BubbleAnimationSet %s invalid frame config: %dx%d count=%d" % [animation_set_id, frame_width, frame_height, frame_count])
		return
	if source_columns <= 0 or source_rows <= 0:
		push_error("BubbleAnimationSet %s invalid layout size: %dx%d" % [animation_set_id, source_columns, source_rows])
		return

	var image := Image.load_from_file(resolved_source_image_path)
	if image == null or image.is_empty():
		push_error("BubbleAnimationSet %s failed to load source image: %s" % [animation_set_id, source_image_path])
		return
	if not _validate_source_image(animation_set_id, source_layout_type, image, frame_width, frame_height, frame_count, source_columns, source_rows):
		return

	var frames := _slice_frames(image, frame_width, frame_height, frame_count, source_columns, source_rows)
	if frames.is_empty():
		push_error("BubbleAnimationSet %s produced no frames" % animation_set_id)
		return

	var sprite_frames := SpriteFrames.new()
	sprite_frames.add_animation("idle")
	sprite_frames.set_animation_speed("idle", idle_fps)
	sprite_frames.set_animation_loop("idle", loop_idle)
	for frame in frames:
		sprite_frames.add_frame("idle", frame)

	var frames_output_path := OUTPUT_FRAMES_DIR + animation_set_id + "_frames.tres"
	if not save_resource(sprite_frames, frames_output_path):
		return

	var def := BubbleAnimationSetDefScript.new()
	def.animation_set_id = animation_set_id
	def.display_name = get_cell(row, header_index, "display_name")
	def.sprite_frames = load(frames_output_path) as SpriteFrames
	def.frame_width = frame_width
	def.frame_height = frame_height
	def.frame_count = frame_count
	def.idle_fps = idle_fps
	def.idle_frame_index = clampi(idle_frame_index, 0, frame_count - 1)
	def.loop_idle = loop_idle
	def.content_hash = get_cell(row, header_index, "content_hash")

	var def_output_path := OUTPUT_DEF_DIR + animation_set_id + ".tres"
	save_resource(def, def_output_path)


func _validate_source_image(
	animation_set_id: String,
	source_layout_type: String,
	image: Image,
	frame_width: int,
	frame_height: int,
	frame_count: int,
	source_columns: int,
	source_rows: int
) -> bool:
	if image.get_width() != frame_width * source_columns or image.get_height() != frame_height * source_rows:
		push_error(
			"BubbleAnimationSet %s source size %dx%d does not match frame/layout %dx%d * %dx%d"
			% [animation_set_id, image.get_width(), image.get_height(), frame_width, frame_height, source_columns, source_rows]
		)
		return false
	if source_layout_type == "strip" and source_rows != 1:
		push_error("BubbleAnimationSet %s strip layout must have source_rows=1" % animation_set_id)
		return false
	if frame_count > source_columns * source_rows:
		push_error("BubbleAnimationSet %s frame_count exceeds layout capacity" % animation_set_id)
		return false
	return true


func _slice_frames(
	image: Image,
	frame_width: int,
	frame_height: int,
	frame_count: int,
	source_columns: int,
	source_rows: int
) -> Array[Texture2D]:
	var frames: Array[Texture2D] = []
	for row_index in range(source_rows):
		for column_index in range(source_columns):
			if frames.size() >= frame_count:
				return frames
			var frame_image := image.get_region(Rect2i(column_index * frame_width, row_index * frame_height, frame_width, frame_height))
			frames.append(ImageTexture.create_from_image(frame_image))
	return frames


func _parse_bool(value: String) -> bool:
	return value.strip_edges().to_lower() == "true"
