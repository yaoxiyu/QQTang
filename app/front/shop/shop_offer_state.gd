class_name ShopOfferState
extends RefCounted

const SELF_SCRIPT = preload("res://app/front/shop/shop_offer_state.gd")

var offer_id: String = ""
var tab_id: String = ""
var goods_id: String = ""
var currency_id: String = ""
var price: int = 0
var limit_type: String = ""
var limit_count: int = 0
var display_name: String = ""
var icon_ui_asset_id: String = ""
var sort_order: int = 0


static func from_dict(data: Dictionary):
	var state = SELF_SCRIPT.new()
	state.offer_id = String(data.get("offer_id", ""))
	state.tab_id = String(data.get("tab_id", ""))
	state.goods_id = String(data.get("goods_id", ""))
	state.currency_id = String(data.get("currency_id", ""))
	state.price = int(data.get("price", 0))
	state.limit_type = String(data.get("limit_type", ""))
	state.limit_count = int(data.get("limit_count", 0))
	state.display_name = String(data.get("display_name", ""))
	state.icon_ui_asset_id = String(data.get("icon_ui_asset_id", ""))
	state.sort_order = int(data.get("sort_order", 0))
	return state
