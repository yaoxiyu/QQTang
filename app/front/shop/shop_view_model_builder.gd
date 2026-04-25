class_name ShopViewModelBuilder
extends RefCounted


func build(catalog, wallet, inventory) -> Dictionary:
	var offers: Array[Dictionary] = []
	if catalog != null:
		for offer in catalog.offers:
			var owned := _is_owned(offer, catalog, inventory)
			var balance: int = wallet.balance_of(offer.currency_id) if wallet != null and wallet.has_method("balance_of") else 0
			offers.append({
				"offer_id": offer.offer_id,
				"display_name": offer.display_name,
				"currency_id": offer.currency_id,
				"price": offer.price,
				"owned": owned,
				"affordable": balance >= int(offer.price),
				"label": "%s | %d %s%s" % [
					offer.display_name,
					int(offer.price),
					offer.currency_id,
					" | owned" if owned else "",
				],
			})
	return {"offers": offers}


func _is_owned(offer, catalog, inventory) -> bool:
	if offer == null or catalog == null or inventory == null:
		return false
	var goods_id := String(offer.goods_id)
	for goods in catalog.goods:
		if String(goods.get("goods_id", "")) == goods_id:
			return inventory.has_asset(String(goods.get("target_asset_type", "")), String(goods.get("target_asset_id", "")))
	return false
