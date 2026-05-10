extends ContentCsvGeneratorBase
class_name GenerateCharacterAnimationSets

const CharacterAnimationSetDefScript = preload("res://content/character_animation_sets/defs/character_animation_set_def.gd")

const INPUT_CSV_PATH := "res://content_source/csv/character_animation_sets/character_animation_sets.csv"
const OUTPUT_DEF_DIR := "res://content/character_animation_sets/data/sets/"
const RUNTIME_STRIP_MANIFEST_PATH := "res://content/character_animation_sets/data/runtime_strips/character_animation_strip_sets.json"
const ASSET_PACK_ID := "qqt-assets"
const DIRECTION_KEYS := ["down", "left", "right", "up"]
const BASE_MOTION_KEYS := ["run", "idle"]
const EXTRA_POSE_KEYS := ["wait", "trigger", "dead", "defeat", "win"]
const EXTRA_POSE_DIRECTION := "down"


func generate() -> void:
	var lines := load_csv_lines(INPUT_CSV_PATH)
	if lines.size() <= 1:
		push_error("character_animation_sets.csv has no data rows")
		return

	var header := split_csv_line(lines[0])
	var header_index := build_header_index(header)
	var seen_animation_set_ids: Dictionary = {}
	var runtime_entries: Array[Dictionary] = []

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
		if _generate_row(row, header_index):
			runtime_entries.append(_build_runtime_manifest_entry(row, header_index))

	_save_runtime_strip_manifest(runtime_entries)


func _generate_row(row: PackedStringArray, header_index: Dictionary) -> bool:
	var animation_set_id := get_cell(row, header_index, "animation_set_id")
	if animation_set_id.is_empty():
		push_error("character_animation_sets.csv animation_set_id is empty")
		return false

	var frame_width := get_cell(row, header_index, "frame_width").to_int()
	var frame_height := get_cell(row, header_index, "frame_height").to_int()
	var frames_per_direction := get_cell(row, header_index, "frames_per_direction").to_int()
	if frame_width <= 0 or frame_height <= 0:
		push_error("CharacterAnimationSet %s invalid frame size: %dx%d" % [animation_set_id, frame_width, frame_height])
		return false
	if frames_per_direction <= 0:
		push_error("CharacterAnimationSet %s invalid frames_per_direction: %d" % [animation_set_id, frames_per_direction])
		return false
	var run_fps := get_cell(row, header_index, "run_fps").to_float()
	if run_fps <= 0.0:
		push_error("CharacterAnimationSet %s invalid run_fps: %s" % [animation_set_id, str(run_fps)])
		return false
	var loop_run := _parse_bool(get_cell(row, header_index, "loop_run"))
	var loop_idle := _parse_bool(get_cell(row, header_index, "loop_idle"))

	var def := CharacterAnimationSetDefScript.new()
	def.animation_set_id = animation_set_id
	def.display_name = get_cell(row, header_index, "display_name")
	def.sprite_frames = null
	def.frame_width = frame_width
	def.frame_height = frame_height
	def.frames_per_direction = frames_per_direction
	def.run_fps = run_fps
	def.idle_frame_index = get_cell(row, header_index, "idle_frame_index").to_int()
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
	return save_resource(def, def_output_path)


func _build_runtime_manifest_entry(row: PackedStringArray, header_index: Dictionary) -> Dictionary:
	return {
		"animation_set_id": get_cell(row, header_index, "animation_set_id"),
		"display_name": get_cell(row, header_index, "display_name"),
		"strips": {
			"run_down": _normalize_strip_uri(_get_motion_strip_path(row, header_index, "run", "down")),
			"run_left": _normalize_strip_uri(_get_motion_strip_path(row, header_index, "run", "left")),
			"run_right": _normalize_strip_uri(_get_motion_strip_path(row, header_index, "run", "right")),
			"run_up": _normalize_strip_uri(_get_motion_strip_path(row, header_index, "run", "up")),
			"idle_down": _normalize_strip_uri(_get_motion_strip_path(row, header_index, "idle", "down")),
			"idle_left": _normalize_strip_uri(_get_motion_strip_path(row, header_index, "idle", "left")),
			"idle_right": _normalize_strip_uri(_get_motion_strip_path(row, header_index, "idle", "right")),
			"idle_up": _normalize_strip_uri(_get_motion_strip_path(row, header_index, "idle", "up")),
			"wait_down": _normalize_strip_uri(_get_pose_strip_path(row, header_index, "wait")),
			"trigger_down": _normalize_strip_uri(_get_pose_strip_path(row, header_index, "trigger")),
			"dead_down": _normalize_strip_uri(_get_pose_strip_path(row, header_index, "dead")),
			"defeat_down": _normalize_strip_uri(_get_pose_strip_path(row, header_index, "defeat")),
			"win_down": _normalize_strip_uri(_get_pose_strip_path(row, header_index, "win")),
		},
		"frame_width": get_cell(row, header_index, "frame_width").to_int(),
		"frame_height": get_cell(row, header_index, "frame_height").to_int(),
		"frames_per_direction": get_cell(row, header_index, "frames_per_direction").to_int(),
		"run_fps": get_cell(row, header_index, "run_fps").to_float(),
		"idle_frame_index": get_cell(row, header_index, "idle_frame_index").to_int(),
		"pivot_origin": {
			"x": get_cell(row, header_index, "pivot_x").to_float(),
			"y": get_cell(row, header_index, "pivot_y").to_float(),
		},
		"pivot_adjust": {
			"x": get_cell(row, header_index, "pivot_adjust_x").to_float(),
			"y": get_cell(row, header_index, "pivot_adjust_y").to_float(),
		},
		"loop_run": _parse_bool(get_cell(row, header_index, "loop_run")),
		"loop_idle": _parse_bool(get_cell(row, header_index, "loop_idle")),
		"content_hash": get_cell(row, header_index, "content_hash"),
	}


func _get_motion_strip_path(row: PackedStringArray, header_index: Dictionary, motion: String, direction: String) -> String:
	var strip_path := get_cell(row, header_index, "%s_%s_strip_path" % [motion, direction])
	if strip_path.is_empty() and motion == "run":
		strip_path = get_cell(row, header_index, "%s_strip_path" % direction)
	return strip_path


func _get_pose_strip_path(row: PackedStringArray, header_index: Dictionary, pose: String) -> String:
	var column_name := "%s_%s_strip_path" % [pose, EXTRA_POSE_DIRECTION]
	var strip_path := get_cell(row, header_index, column_name)
	if not strip_path.is_empty():
		return strip_path

	match pose:
		"trigger":
			return get_cell(row, header_index, "trapped_%s_strip_path" % EXTRA_POSE_DIRECTION)
		"win":
			return get_cell(row, header_index, "victory_%s_strip_path" % EXTRA_POSE_DIRECTION)
		_:
			return ""


func _normalize_strip_uri(strip_path: String) -> String:
	if strip_path.is_empty() or strip_path.begins_with("asset://"):
		return strip_path
	if strip_path.begins_with("res://external/"):
		return "asset://%s/derived/%s" % [ASSET_PACK_ID, strip_path.trim_prefix("res://external/")]
	return strip_path


func _save_runtime_strip_manifest(entries: Array[Dictionary]) -> void:
	var manifest := {
		"schema_version": 1,
		"generated_by": "tools/content_pipeline/generators/generate_character_animation_sets.gd",
		"entries": entries,
	}
	var json := JSON.stringify(manifest, "\t")
	var file := FileAccess.open(RUNTIME_STRIP_MANIFEST_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Failed to open runtime strip manifest for write: %s" % RUNTIME_STRIP_MANIFEST_PATH)
		return
	file.store_string(json)
	file.close()


func _parse_bool(value: String) -> bool:
	return value.strip_edges().to_lower() == "true"
