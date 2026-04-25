class_name ShopCatalogState
extends RefCounted

const ShopOfferStateScript = preload("res://app/front/shop/shop_offer_state.gd")
const SELF_SCRIPT = preload("res://app/front/shop/shop_catalog_state.gd")

var catalog_revision: int = 0
var currencies: Array[Dictionary] = []
var tabs: Array[Dictionary] = []
var goods: Array[Dictionary] = []
var offers: Array = []
var last_sync_msec: int = 0


static func from_response(data: Dictionary, previous = null):
	if bool(data.get("not_modified", false)) and previous != null:
		return previous
	var state = SELF_SCRIPT.new()
	state.catalog_revision = int(data.get("catalog_revision", 0))
	state.currencies = _dict_array(data.get("currencies", []))
	state.tabs = _dict_array(data.get("tabs", []))
	state.goods = _dict_array(data.get("goods", []))
	var raw_offers: Variant = data.get("offers", [])
	if raw_offers is Array:
		for item in raw_offers:
			if item is Dictionary:
				state.offers.append(ShopOfferStateScript.from_dict(item))
	state.last_sync_msec = Time.get_ticks_msec()
	return state


func find_offer(offer_id: String):
	for offer in offers:
		if offer.offer_id == offer_id:
			return offer
	return null


static func _dict_array(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if value is Array:
		for item in value:
			if item is Dictionary:
				result.append((item as Dictionary).duplicate(true))
	return result
