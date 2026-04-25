class_name UiAssetResolver
extends RefCounted

const UiAssetCatalogScript = preload("res://app/front/ui_resources/ui_asset_catalog.gd")
const PLACEHOLDER_ASSET_ID := "ui.placeholder.missing"

var catalog = null
var strict_missing: bool = false


func configure(p_catalog = null, p_strict_missing: bool = false) -> void:
	catalog = p_catalog if p_catalog != null else UiAssetCatalogScript.load_from_path()
	strict_missing = p_strict_missing


func resolve_path(asset_id: String) -> Dictionary:
	_ensure_catalog()
	var asset: Dictionary = catalog.get_asset(asset_id) if catalog != null else {}
	if asset.is_empty():
		return _missing_result(asset_id, "UI_ASSET_ID_MISSING")
	var resource_path := String(asset.get("resource_path", ""))
	if resource_path.is_empty():
		return _missing_result(asset_id, "UI_ASSET_PATH_MISSING")
	if ResourceLoader.exists(resource_path):
		return {"ok": true, "asset_id": asset_id, "resource_path": resource_path, "asset": asset}
	return _missing_result(asset_id, "UI_ASSET_RESOURCE_MISSING")


func load_resource(asset_id: String):
	var result := resolve_path(asset_id)
	if not bool(result.get("ok", false)):
		return null
	return ResourceLoader.load(String(result.get("resource_path", "")))


func _ensure_catalog() -> void:
	if catalog == null:
		catalog = UiAssetCatalogScript.load_from_path()


func _missing_result(asset_id: String, error_code: String) -> Dictionary:
	if strict_missing:
		return {"ok": false, "asset_id": asset_id, "error_code": error_code, "resource_path": ""}
	var placeholder: Dictionary = catalog.get_asset(PLACEHOLDER_ASSET_ID) if catalog != null else {}
	return {
		"ok": not placeholder.is_empty(),
		"asset_id": asset_id,
		"error_code": error_code,
		"resource_path": String(placeholder.get("resource_path", "")),
		"placeholder": true,
	}
