extends ContentCsvGeneratorBase
class_name GenerateVfxAnimationSets

const VfxAnimationSetDefScript = preload("res://content/vfx_animation_sets/defs/vfx_animation_set_def.gd")
const AssetPathResolverScript = preload("res://content/assets/runtime/asset_path_resolver.gd")

const INPUT_CSV_PATH := "res://content_source/csv/vfx_animation_sets/vfx_animation_sets.csv"
const OUTPUT_DEF_DIR := "res://content/vfx_animation_sets/data/sets/"
const ASSET_PACK_ID := "qqt-assets"


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
	var enter_frames := get_cell(row, header_index, "enter_frames").to_int()
	var loop_frames := get_cell(row, header_index, "loop_frames").to_int()
	var release_frames := get_cell(row, header_index, "release_frames").to_int()
	if enter_frames <= 0 or loop_frames <= 0 or release_frames <= 0:
		push_error("VfxAnimationSet %s invalid frame counts" % vfx_set_id)
		return
	var def := VfxAnimationSetDefScript.new()
	def.vfx_set_id = vfx_set_id
	def.display_name = get_cell(row, header_index, "display_name")
	def.sprite_frames = null
	def.enter_strip_path = _normalize_strip_uri(get_cell(row, header_index, "enter_strip_path"))
	def.loop_strip_path = _normalize_strip_uri(get_cell(row, header_index, "loop_strip_path"))
	def.release_strip_path = _normalize_strip_uri(get_cell(row, header_index, "release_strip_path"))
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


func _normalize_strip_uri(strip_path: String) -> String:
	if strip_path.begins_with("res://external/assets/derived/"):
		return "asset://%s/derived/%s" % [ASSET_PACK_ID, strip_path.trim_prefix("res://external/assets/derived/")]
	if strip_path.begins_with("res://external/assets/"):
		return "asset://%s/derived/assets/%s" % [ASSET_PACK_ID, strip_path.trim_prefix("res://external/assets/")]
	if strip_path.begins_with("res://external/"):
		return "asset://%s/derived/%s" % [ASSET_PACK_ID, strip_path.trim_prefix("res://external/")]
	return strip_path
