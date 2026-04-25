class_name InventoryAssetState
extends RefCounted

const SELF_SCRIPT = preload("res://app/front/inventory/inventory_asset_state.gd")

var asset_type: String = ""
var asset_id: String = ""
var state: String = ""
var quantity: int = 1
var acquired_at: String = ""
var expire_at = null
var source_type: String = ""
var source_ref_id: String = ""
var revision: int = 0


static func from_dict(data: Dictionary):
	var item = SELF_SCRIPT.new()
	item.asset_type = String(data.get("asset_type", ""))
	item.asset_id = String(data.get("asset_id", ""))
	item.state = String(data.get("state", ""))
	item.quantity = int(data.get("quantity", 1))
	item.acquired_at = String(data.get("acquired_at", ""))
	item.expire_at = data.get("expire_at", null)
	item.source_type = String(data.get("source_type", ""))
	item.source_ref_id = String(data.get("source_ref_id", ""))
	item.revision = int(data.get("revision", 0))
	return item


func is_usable() -> bool:
	return state == "owned"
