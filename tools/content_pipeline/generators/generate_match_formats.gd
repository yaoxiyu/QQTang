extends ContentCsvGeneratorBase
class_name GenerateMatchFormats

const ContentHashUtilScript = preload("res://tools/content_pipeline/common/content_hash_util.gd")
const INPUT_CSV_PATH := "res://content_source/csv/match_formats/match_formats.csv"
const OUTPUT_DIR := "res://content/match_formats/data/formats/"


func generate() -> void:
	var csv_rows := read_csv_rows(INPUT_CSV_PATH)
	if csv_rows.is_empty():
		record_error("generate_match_formats.gd: match_formats.csv has no data rows")
		return

	var csv_reader := ContentCsvReaderScript.new()
	var valid_match_format_ids: Array[String] = []
	for row in csv_rows:
		var def := MatchFormatDef.new()
		def.match_format_id = csv_reader.require_string(row, "match_format_id")
		def.display_name = csv_reader.require_string(row, "display_name")
		def.team_count = csv_reader.parse_int(row.get("team_count", ""), 0)
		def.required_party_size = csv_reader.parse_int(row.get("required_party_size", ""), 0)
		def.map_pool_resolution_policy = csv_reader.require_string(row, "map_pool_resolution_policy")
		def.sort_order = csv_reader.parse_int(row.get("sort_order", ""), 0)
		def.enabled_in_match_room = csv_reader.parse_bool(row.get("enabled_in_match_room", "false"), false)

		if def.match_format_id.is_empty():
			record_error("generate_match_formats.gd: encountered empty match_format_id")
			continue
		if def.team_count <= 0:
			record_error("generate_match_formats.gd: invalid team_count for %s" % def.match_format_id)
			continue
		if def.required_party_size <= 0:
			record_error("generate_match_formats.gd: invalid required_party_size for %s" % def.match_format_id)
			continue

		def.expected_total_player_count = def.team_count * def.required_party_size
		def.content_hash = ContentHashUtilScript.hash_dictionary({
			"match_format_id": def.match_format_id,
			"display_name": def.display_name,
			"team_count": def.team_count,
			"required_party_size": def.required_party_size,
			"expected_total_player_count": def.expected_total_player_count,
			"map_pool_resolution_policy": def.map_pool_resolution_policy,
			"sort_order": def.sort_order,
			"enabled_in_match_room": def.enabled_in_match_room,
		})

		var output_path := OUTPUT_DIR + def.match_format_id + ".tres"
		save_resource(def, output_path)
		valid_match_format_ids.append(def.match_format_id)
	_prune_stale_resources(valid_match_format_ids)


func _prune_stale_resources(valid_match_format_ids: Array[String]) -> void:
	var valid_id_set: Dictionary = {}
	for match_format_id in valid_match_format_ids:
		valid_id_set[match_format_id] = true

	for file_name in DirAccess.get_files_at(OUTPUT_DIR):
		if not file_name.ends_with(".tres"):
			continue
		var match_format_id := file_name.trim_suffix(".tres")
		if valid_id_set.has(match_format_id):
			continue
		var stale_path := OUTPUT_DIR + file_name
		var err := DirAccess.remove_absolute(ProjectSettings.globalize_path(stale_path))
		if err != OK:
			record_error("generate_match_formats.gd: failed to delete stale match format resource %s err=%d" % [stale_path, err])
