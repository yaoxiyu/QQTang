class_name ContentValidationReport
extends RefCounted

const ContentCsvReaderScript = preload("res://tools/content_pipeline/common/content_csv_reader.gd")
const MapResourceScript = preload("res://content/maps/resources/map_resource.gd")
const MatchFormatCatalogScript = preload("res://content/match_formats/catalog/match_format_catalog.gd")
const MapThemeCatalogScript = preload("res://content/map_themes/catalog/map_theme_catalog.gd")
const ModeCatalogScript = preload("res://content/modes/catalog/mode_catalog.gd")
const RuleSetCatalogScript = preload("res://content/rulesets/catalog/rule_set_catalog.gd")

const MAPS_CSV_PATH := "res://content_source/csv/maps/maps.csv"
const MAP_VARIANTS_CSV_PATH := "res://content_source/csv/maps/map_match_variants.csv"
const MATCH_FORMATS_CSV_PATH := "res://content_source/csv/match_formats/match_formats.csv"
const MAP_RESOURCE_DIR := "res://content/maps/resources"
const REPORT_DIR := "res://build/generated/content_reports"
const JSON_OUTPUT_PATH := REPORT_DIR + "/content_pipeline_report.json"
const MARKDOWN_OUTPUT_PATH := REPORT_DIR + "/content_pipeline_report.md"


func generate() -> Dictionary:
	var csv_reader := ContentCsvReaderScript.new()
	var maps_rows := csv_reader.read_rows(MAPS_CSV_PATH)
	var variant_rows := csv_reader.read_rows(MAP_VARIANTS_CSV_PATH)
	var match_format_rows := csv_reader.read_rows(MATCH_FORMATS_CSV_PATH)

	ModeCatalogScript.load_all()
	RuleSetCatalogScript.load_all()
	MapThemeCatalogScript.load_all()
	MatchFormatCatalogScript.load_all()

	var report := {
		"generated_at_unix_ms": int(Time.get_unix_time_from_system() * 1000.0),
		"summary": {
			"maps_total": maps_rows.size(),
			"map_variants_total": variant_rows.size(),
			"match_formats_total": match_format_rows.size(),
		},
		"errors": [],
		"warnings": [],
		"orphan_map_resources": [],
		"orphan_source_rows": [],
		"variant_invalid_references": [],
		"spawn_point_violations": [],
		"missing_mode_or_rule": [],
		"missing_themes": [],
		"map_mode_rule_match_formats": [],
	}

	var source_map_ids: Dictionary = {}
	var variants_by_map_id: Dictionary = {}
	for map_row in maps_rows:
		var map_id := String(map_row.get("map_id", "")).strip_edges()
		if map_id.is_empty():
			continue
		source_map_ids[map_id] = map_row
	for variant_row in variant_rows:
		var map_id := String(variant_row.get("map_id", "")).strip_edges()
		if map_id.is_empty():
			continue
		if not variants_by_map_id.has(map_id):
			variants_by_map_id[map_id] = []
		var bucket: Array = variants_by_map_id[map_id]
		bucket.append(variant_row)

	var resource_map_ids: Dictionary = {}
	for file_name in DirAccess.get_files_at(MAP_RESOURCE_DIR):
		if not file_name.ends_with(".tres"):
			continue
		var resource_path := "%s/%s" % [MAP_RESOURCE_DIR, file_name]
		var resource := load(resource_path)
		if resource == null or not resource is MapResourceScript:
			_append_error(report, "invalid map resource: %s" % resource_path)
			continue
		var map_resource := resource as MapResource
		if map_resource.map_id.is_empty():
			_append_error(report, "map resource has empty map_id: %s" % resource_path)
			continue
		resource_map_ids[map_resource.map_id] = resource_path
		if not source_map_ids.has(map_resource.map_id):
			_append_unique_string(report["orphan_map_resources"], map_resource.map_id)
			_append_error(report, "orphan map resource without source row: %s" % map_resource.map_id)

	for map_id in source_map_ids.keys():
		var source_row: Dictionary = source_map_ids[map_id]
		if not resource_map_ids.has(map_id):
			_append_unique_string(report["orphan_source_rows"], String(map_id))
			_append_error(report, "source map row has no generated resource: %s" % String(map_id))

		var bound_mode_id := String(source_row.get("bound_mode_id", "")).strip_edges()
		var bound_rule_set_id := String(source_row.get("bound_rule_set_id", "")).strip_edges()
		var theme_id := String(source_row.get("theme_id", "")).strip_edges()
		if bound_mode_id.is_empty() or not ModeCatalogScript.has_mode(bound_mode_id):
			_append_missing_mode_or_rule(report, String(map_id), "mode", bound_mode_id)
			_append_error(report, "map %s references missing mode_id=%s" % [String(map_id), bound_mode_id])
		if bound_rule_set_id.is_empty() or not RuleSetCatalogScript.has_rule(bound_rule_set_id):
			_append_missing_mode_or_rule(report, String(map_id), "rule_set", bound_rule_set_id)
			_append_error(report, "map %s references missing rule_set_id=%s" % [String(map_id), bound_rule_set_id])
		if theme_id.is_empty() or not MapThemeCatalogScript.has_id(theme_id):
			_append_missing_theme(report, String(map_id), theme_id)
			_append_error(report, "map %s references missing theme_id=%s" % [String(map_id), theme_id])

		var spawn_points := csv_reader.parse_vector2i_list(source_row.get("spawn_points", ""))
		var map_variants: Array = variants_by_map_id.get(map_id, [])
		if map_variants.is_empty():
			_append_invalid_variant_reference(report, String(map_id), "", "missing variant rows")
			_append_error(report, "map %s has no map_match_variants rows" % String(map_id))
		var format_ids_for_relation: Array[String] = []
		for variant_row in map_variants:
			if not variant_row is Dictionary:
				continue
			var match_format_id := String((variant_row as Dictionary).get("match_format_id", "")).strip_edges()
			if match_format_id.is_empty() or not MatchFormatCatalogScript.has_match_format(match_format_id):
				_append_invalid_variant_reference(report, String(map_id), match_format_id, "unknown match_format_id")
				_append_error(report, "map %s variant references missing match_format_id=%s" % [String(map_id), match_format_id])
				continue
			format_ids_for_relation.append(match_format_id)
			var expected_total_player_count := MatchFormatCatalogScript.get_expected_total_player_count(match_format_id)
			if spawn_points.size() < expected_total_player_count:
				_append_spawn_violation(report, String(map_id), match_format_id, spawn_points.size(), expected_total_player_count)
				_append_error(
					report,
					"map %s spawn_points insufficient for %s: actual=%d expected=%d"
					% [String(map_id), match_format_id, spawn_points.size(), expected_total_player_count]
				)
		(report["map_mode_rule_match_formats"] as Array).append({
			"map_id": String(map_id),
			"mode_id": bound_mode_id,
			"rule_set_id": bound_rule_set_id,
			"match_format_ids": _sorted_unique_strings(format_ids_for_relation),
		})

	_ensure_report_dir()
	_write_json_report(report)
	_write_markdown_report(report)
	return report


func _append_error(report: Dictionary, message: String) -> void:
	_append_unique_string(report["errors"], message)


func _append_invalid_variant_reference(report: Dictionary, map_id: String, match_format_id: String, reason: String) -> void:
	(report["variant_invalid_references"] as Array).append({
		"map_id": map_id,
		"match_format_id": match_format_id,
		"reason": reason,
	})


func _append_spawn_violation(report: Dictionary, map_id: String, match_format_id: String, actual: int, expected: int) -> void:
	(report["spawn_point_violations"] as Array).append({
		"map_id": map_id,
		"match_format_id": match_format_id,
		"spawn_points": actual,
		"expected_total_player_count": expected,
	})


func _append_missing_mode_or_rule(report: Dictionary, map_id: String, kind: String, value: String) -> void:
	(report["missing_mode_or_rule"] as Array).append({
		"map_id": map_id,
		"kind": kind,
		"value": value,
	})


func _append_missing_theme(report: Dictionary, map_id: String, theme_id: String) -> void:
	(report["missing_themes"] as Array).append({
		"map_id": map_id,
		"theme_id": theme_id,
	})


func _append_unique_string(target: Variant, value: String) -> void:
	if not target is Array:
		return
	var array := target as Array
	if array.has(value):
		return
	array.append(value)


func _sorted_unique_strings(values: Array[String]) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		if value.is_empty() or result.has(value):
			continue
		result.append(value)
	result.sort()
	return result


func _write_json_report(report: Dictionary) -> void:
	var file := FileAccess.open(JSON_OUTPUT_PATH, FileAccess.WRITE)
	if file == null:
		push_error("ContentValidationReport failed to open json output: %s" % JSON_OUTPUT_PATH)
		return
	file.store_string(JSON.stringify(report, "\t"))
	file.close()


func _write_markdown_report(report: Dictionary) -> void:
	var summary := report.get("summary", {}) as Dictionary
	var lines: Array[String] = []
	lines.append("# Content Pipeline Report")
	lines.append("")
	lines.append("## Summary")
	lines.append("- maps_total: %d" % int(summary.get("maps_total", 0)))
	lines.append("- map_variants_total: %d" % int(summary.get("map_variants_total", 0)))
	lines.append("- match_formats_total: %d" % int(summary.get("match_formats_total", 0)))
	lines.append("- error_count: %d" % (report.get("errors", []) as Array).size())
	lines.append("")
	lines.append("## Errors")
	if (report.get("errors", []) as Array).is_empty():
		lines.append("- none")
	else:
		for message in report.get("errors", []):
			lines.append("- %s" % String(message))
	lines.append("")
	lines.append("## Orphans")
	lines.append("- orphan_map_resources: %s" % _join_strings(report.get("orphan_map_resources", [])))
	lines.append("- orphan_source_rows: %s" % _join_strings(report.get("orphan_source_rows", [])))
	lines.append("")
	lines.append("## Variant Invalid References")
	lines.append_array(_dict_section_lines(report.get("variant_invalid_references", [])))
	lines.append("")
	lines.append("## Spawn Point Violations")
	lines.append_array(_dict_section_lines(report.get("spawn_point_violations", [])))
	lines.append("")
	lines.append("## Missing Mode Or Rule")
	lines.append_array(_dict_section_lines(report.get("missing_mode_or_rule", [])))
	lines.append("")
	lines.append("## Missing Themes")
	lines.append_array(_dict_section_lines(report.get("missing_themes", [])))
	lines.append("")
	lines.append("## Map Relations")
	lines.append_array(_dict_section_lines(report.get("map_mode_rule_match_formats", [])))

	var file := FileAccess.open(MARKDOWN_OUTPUT_PATH, FileAccess.WRITE)
	if file == null:
		push_error("ContentValidationReport failed to open markdown output: %s" % MARKDOWN_OUTPUT_PATH)
		return
	file.store_string("\n".join(lines) + "\n")
	file.close()


func _dict_section_lines(entries_variant: Variant) -> Array[String]:
	var lines: Array[String] = []
	if not entries_variant is Array or (entries_variant as Array).is_empty():
		lines.append("- none")
		return lines
	for entry in entries_variant:
		if not entry is Dictionary:
			continue
		lines.append("- `%s`" % JSON.stringify(entry))
	return lines


func _join_strings(values_variant: Variant) -> String:
	if not values_variant is Array or (values_variant as Array).is_empty():
		return "none"
	var values: Array[String] = []
	for value in values_variant:
		values.append(String(value))
	return ", ".join(values)


func _ensure_report_dir() -> void:
	var global_dir := ProjectSettings.globalize_path(REPORT_DIR)
	DirAccess.make_dir_recursive_absolute(global_dir)
