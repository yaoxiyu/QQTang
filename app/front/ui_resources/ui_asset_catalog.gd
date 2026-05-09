class_name UiAssetCatalog
extends RefCounted

const DEFAULT_CSV_PATH := "res://content_source/csv/ui/ui_asset_catalog.csv"
const DEFAULT_CATALOG_PATH := "res://content/ui_assets/catalog/ui_asset_catalog.json"
const SELF_SCRIPT = preload("res://app/front/ui_resources/ui_asset_catalog.gd")

var catalog_revision: int = 0
var assets_by_id: Dictionary = {}


static func load_from_path(path: String = ""):
	var catalog = SELF_SCRIPT.new()
	if path.is_empty():
		if FileAccess.file_exists(DEFAULT_CSV_PATH):
			return load_from_csv_path(DEFAULT_CSV_PATH)
		path = DEFAULT_CATALOG_PATH
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return catalog
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return catalog
	var data = json.data
	if not (data is Dictionary):
		return catalog
	catalog.catalog_revision = int(data.get("catalog_revision", 0))
	var assets: Variant = data.get("assets", [])
	if assets is Array:
		for item in assets:
			if item is Dictionary and bool(item.get("enabled", false)):
				var asset_id := String(item.get("asset_id", ""))
				if not asset_id.is_empty():
					catalog.assets_by_id[asset_id] = item.duplicate(true)
	return catalog


static func load_from_csv_path(path: String = DEFAULT_CSV_PATH):
	var catalog = SELF_SCRIPT.new()
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return catalog
	var header_line := file.get_line()
	if header_line.is_empty():
		return catalog
	var headers := header_line.split(",", true)
	while not file.eof_reached():
		var line := file.get_line()
		if line.strip_edges().is_empty():
			continue
		var cols := line.split(",", true)
		if cols.size() < headers.size():
			continue
		var row := _csv_row_to_asset_dict(headers, cols)
		if row.is_empty():
			continue
		if not bool(row.get("enabled", false)):
			continue
		var asset_id := String(row.get("asset_id", ""))
		if asset_id.is_empty():
			continue
		catalog.assets_by_id[asset_id] = row
	return catalog


static func _csv_row_to_asset_dict(headers: Array, cols: Array) -> Dictionary:
	var row: Dictionary = {}
	for index in range(headers.size()):
		var key := String(headers[index]).strip_edges()
		var raw := ""
		if index < cols.size():
			raw = String(cols[index]).strip_edges()
		row[key] = raw
	if row.is_empty():
		return {}
	return {
		"asset_id": String(row.get("asset_id", "")),
		"asset_kind": String(row.get("asset_kind", "")),
		"resource_path": String(row.get("resource_path", "")),
		"default_width": int(String(row.get("default_width", "0")).to_int()),
		"default_height": int(String(row.get("default_height", "0")).to_int()),
		"nine_patch": _parse_csv_bool(String(row.get("nine_patch", "false"))),
		"scale_mode": String(row.get("scale_mode", "")),
		"tags": String(row.get("tags", "")),
		"enabled": _parse_csv_bool(String(row.get("enabled", "false"))),
	}


static func _parse_csv_bool(value: String) -> bool:
	var normalized := value.strip_edges().to_lower()
	return normalized == "1" or normalized == "true" or normalized == "yes"


func has_asset(asset_id: String) -> bool:
	return assets_by_id.has(asset_id)


func get_asset(asset_id: String) -> Dictionary:
	return assets_by_id.get(asset_id, {})
