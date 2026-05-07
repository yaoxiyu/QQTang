extends ContentCsvGeneratorBase
class_name GenerateMapElements

const ContentHashUtilScript = preload("res://tools/content_pipeline/common/content_hash_util.gd")
const MapElementDefScript = preload("res://content/map_elements/defs/map_element_def.gd")

const CSV_PATH := "res://content_source/csv/map_elements/map_elements.csv"
const OUTPUT_DIR := "res://content/map_elements/resources/"


func generate() -> void:
	var csv_reader := ContentCsvReaderScript.new()
	var rows := csv_reader.read_rows(CSV_PATH)
	if rows.is_empty():
		record_error("generate_map_elements.gd: map_elements.csv has no data rows")
		return

	var valid_ids: Array[String] = []
	for row in rows:
		var element_id_str := csv_reader.require_string(row, "element_id")
		if element_id_str.is_empty():
			record_error("generate_map_elements.gd: row missing element_id")
			continue
		if not element_id_str.is_valid_int():
			record_error("generate_map_elements.gd: invalid element_id=%s" % element_id_str)
			continue

		var element_id := element_id_str.to_int()
		var def := _build_element_def(row, element_id, csv_reader)
		if def == null:
			continue

		valid_ids.append(element_id_str)
		var output_path := OUTPUT_DIR + element_id_str + ".tres"
		save_resource(def, output_path)

	_prune_stale_resources(valid_ids)


func _build_element_def(row: Dictionary, element_id: int, csv_reader: ContentCsvReader) -> Resource:
	var display_name := csv_reader.require_string(row, "display_name")
	var mode_id := csv_reader.require_string(row, "mode_id")
	var mode_name := csv_reader.require_string(row, "mode_name")
	var elem_number := csv_reader.parse_int(row.get("elem_number", ""), 0)
	var logic_type := csv_reader.parse_int(row.get("logic_type", ""), 0)
	var interact_type := csv_reader.parse_int(row.get("interact_type", "0"), 0)
	var source_dir := csv_reader.require_string(row, "source_dir")
	var stand_file := csv_reader.optional_string(row, "stand_file", "")
	var die_file := csv_reader.optional_string(row, "die_file", "")
	var trigger_file := csv_reader.optional_string(row, "trigger_file", "")

	var def := MapElementDefScript.new()
	def.element_id = element_id
	def.display_name = display_name
	def.mode_id = mode_id
	def.mode_name = mode_name
	def.elem_number = elem_number
	def.logic_type = logic_type
	def.interact_type = interact_type
	def.source_dir = source_dir
	def.stand_file = stand_file
	def.die_file = die_file
	def.trigger_file = trigger_file
	def.content_hash = ContentHashUtilScript.hash_dictionary({
		"element_id": def.element_id,
		"display_name": def.display_name,
		"mode_id": def.mode_id,
		"mode_name": def.mode_name,
		"elem_number": def.elem_number,
		"logic_type": def.logic_type,
		"interact_type": def.interact_type,
		"source_dir": def.source_dir,
		"stand_file": def.stand_file,
		"die_file": def.die_file,
		"trigger_file": def.trigger_file,
	})
	return def


func _prune_stale_resources(valid_ids: Array[String]) -> void:
	var valid_set: Dictionary = {}
	for id_str in valid_ids:
		valid_set[id_str] = true

	for file_name in DirAccess.get_files_at(OUTPUT_DIR):
		if not file_name.ends_with(".tres"):
			continue
		var res_id := file_name.trim_suffix(".tres")
		if valid_set.has(res_id):
			continue
		var stale_path := OUTPUT_DIR + file_name
		var err := DirAccess.remove_absolute(ProjectSettings.globalize_path(stale_path))
		if err != OK:
			record_error("generate_map_elements.gd: failed to delete stale resource %s err=%d" % [stale_path, err])
