class_name ContentCsvReader
extends RefCounted


func read_rows(csv_path: String) -> Array[Dictionary]:
	var file := FileAccess.open(csv_path, FileAccess.READ)
	if file == null:
		push_error("ContentCsvReader failed to open csv: %s" % csv_path)
		return []

	var header_row := _read_next_non_empty_csv_row(file)
	if header_row.is_empty():
		push_error("ContentCsvReader missing header row: %s" % csv_path)
		return []

	var headers: Array[String] = []
	var seen_headers: Dictionary = {}
	for raw_header in header_row:
		var header := String(raw_header).strip_edges()
		if header.is_empty():
			push_error("ContentCsvReader found empty header in csv: %s" % csv_path)
			return []
		if seen_headers.has(header):
			push_error("ContentCsvReader found duplicate header '%s' in csv: %s" % [header, csv_path])
			return []
		seen_headers[header] = true
		headers.append(header)

	var rows: Array[Dictionary] = []
	var primary_key := headers[0]
	var row_index := 1
	while not file.eof_reached():
		var values := file.get_csv_line()
		if values.is_empty():
			continue
		if _is_effectively_empty_row(values):
			continue
		if values.size() != headers.size():
			push_error(
				"ContentCsvReader row column count mismatch in %s at row %d: expected=%d actual=%d"
				% [csv_path, row_index + 1, headers.size(), values.size()]
			)
			row_index += 1
			continue

		var row: Dictionary = {}
		for i in range(headers.size()):
			row[headers[i]] = String(values[i]).strip_edges()

		if String(row.get(primary_key, "")).is_empty():
			push_error("ContentCsvReader row %d has empty primary key '%s' in %s" % [row_index + 1, primary_key, csv_path])
			row_index += 1
			continue
		rows.append(row)
		row_index += 1

	return rows


func require_string(row: Dictionary, key: String) -> String:
	var value := String(row.get(key, "")).strip_edges()
	if value.is_empty():
		push_error("ContentCsvReader missing required field '%s'" % key)
	return value


func optional_string(row: Dictionary, key: String, default_value: String = "") -> String:
	var value := String(row.get(key, default_value)).strip_edges()
	if value.is_empty():
		return default_value
	return value


func parse_bool(value: Variant, default_value: bool = false) -> bool:
	var normalized := String(value).strip_edges().to_lower()
	if normalized.is_empty():
		return default_value
	if normalized in ["true", "1", "yes", "y"]:
		return true
	if normalized in ["false", "0", "no", "n"]:
		return false
	push_error("ContentCsvReader.parse_bool invalid bool value: %s" % String(value))
	return default_value


func parse_int(value: Variant, default_value: int = 0) -> int:
	var normalized := String(value).strip_edges()
	if normalized.is_empty():
		return default_value
	if not normalized.is_valid_int():
		push_error("ContentCsvReader.parse_int invalid int value: %s" % normalized)
		return default_value
	return normalized.to_int()


func parse_semicolon_list(value: Variant) -> PackedStringArray:
	var normalized := String(value).strip_edges()
	if normalized.is_empty():
		return PackedStringArray()
	return PackedStringArray(normalized.split(";", false))


func parse_vector2i_list(value: Variant) -> Array[Vector2i]:
	var entries := parse_semicolon_list(value)
	var result: Array[Vector2i] = []
	for entry in entries:
		var coords := String(entry).split(":", false)
		if coords.size() != 2:
			push_error("ContentCsvReader.parse_vector2i_list invalid vector entry: %s" % String(entry))
			continue
		var x_text := String(coords[0]).strip_edges()
		var y_text := String(coords[1]).strip_edges()
		if not x_text.is_valid_int() or not y_text.is_valid_int():
			push_error("ContentCsvReader.parse_vector2i_list invalid vector numbers: %s" % String(entry))
			continue
		result.append(Vector2i(x_text.to_int(), y_text.to_int()))
	return result


func _read_next_non_empty_csv_row(file: FileAccess) -> PackedStringArray:
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.is_empty():
			continue
		if _is_effectively_empty_row(row):
			continue
		return row
	return PackedStringArray()


func _is_effectively_empty_row(row: PackedStringArray) -> bool:
	for cell in row:
		if not String(cell).strip_edges().is_empty():
			return false
	return true
