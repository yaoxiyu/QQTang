class_name UiAssetCatalog
extends RefCounted

const DEFAULT_CATALOG_PATH := "res://content/ui_assets/catalog/ui_asset_catalog.json"
const SELF_SCRIPT = preload("res://app/front/ui_resources/ui_asset_catalog.gd")

var catalog_revision: int = 0
var assets_by_id: Dictionary = {}


static func load_from_path(path: String = DEFAULT_CATALOG_PATH):
	var catalog = SELF_SCRIPT.new()
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


func has_asset(asset_id: String) -> bool:
	return assets_by_id.has(asset_id)


func get_asset(asset_id: String) -> Dictionary:
	return assets_by_id.get(asset_id, {})
