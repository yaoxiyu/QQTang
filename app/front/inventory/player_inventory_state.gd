class_name PlayerInventoryState
extends RefCounted

const InventoryAssetStateScript = preload("res://app/front/inventory/inventory_asset_state.gd")
const SELF_SCRIPT = preload("res://app/front/inventory/player_inventory_state.gd")

var profile_id: String = ""
var owned_asset_revision: int = 0
var assets: Array = []
var last_sync_msec: int = 0


static func from_response(data: Dictionary):
	var state = SELF_SCRIPT.new()
	state.profile_id = String(data.get("profile_id", ""))
	state.owned_asset_revision = int(data.get("owned_asset_revision", 0))
	state.last_sync_msec = Time.get_ticks_msec()
	var raw_assets: Variant = data.get("assets", [])
	if raw_assets is Array:
		for item in raw_assets:
			if item is Dictionary:
				state.assets.append(InventoryAssetStateScript.from_dict(item))
	return state


func has_asset(asset_type: String, asset_id: String) -> bool:
	for item in assets:
		if item.asset_type == asset_type and item.asset_id == asset_id and item.is_usable():
			return true
	return false
