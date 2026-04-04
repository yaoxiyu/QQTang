extends RefCounted
class_name ContentCsvGeneratorBase

func load_csv_lines(csv_path: String) -> Array[String]:
    var file := FileAccess.open(csv_path, FileAccess.READ)
    if file == null:
        push_error("Failed to open csv: %s" % csv_path)
        return []

    var lines: Array[String] = []
    while not file.eof_reached():
        var line := file.get_line()
        if line.strip_edges() == "":
            continue
        lines.append(line)
    return lines

func split_csv_line(line: String) -> PackedStringArray:
    return line.split(",", true)

func build_header_index(header: PackedStringArray) -> Dictionary:
    var result: Dictionary = {}
    for i in range(header.size()):
        result[header[i]] = i
    return result

func get_cell(row: PackedStringArray, header_index: Dictionary, key: String) -> String:
    if not header_index.has(key):
        return ""
    var idx: int = int(header_index[key])
    if idx < 0 or idx >= row.size():
        return ""
    return row[idx].strip_edges()

func split_semicolon(value: String) -> PackedStringArray:
    if value.strip_edges() == "":
        return PackedStringArray()
    return PackedStringArray(value.split(";", false))

func load_resource_or_null(path: String) -> Resource:
    if path.strip_edges() == "":
        return null
    return load(path)

func save_resource(resource: Resource, output_path: String) -> bool:
    var err := ResourceSaver.save(resource, output_path)
    if err != OK:
        push_error("Failed to save resource: %s, err=%d" % [output_path, err])
        return false
    return true
