class_name InventoryViewModelBuilder
extends RefCounted


func build(inventory, profile = null) -> Dictionary:
	var assets: Array[Dictionary] = []
	if inventory != null:
		for item in inventory.assets:
			var equipped := _is_equipped(item, profile)
			assets.append({
				"asset_type": item.asset_type,
				"asset_id": item.asset_id,
				"state": item.state,
				"quantity": item.quantity,
				"equipped": equipped,
				"label": "%s:%s x%d%s" % [
					item.asset_type,
					item.asset_id,
					int(item.quantity),
					" | equipped" if equipped else "",
				],
			})
	return {"assets": assets}


func _is_equipped(item, profile) -> bool:
	if item == null or profile == null:
		return false
	match String(item.asset_type):
		"character":
			return String(profile.default_character_id) == String(item.asset_id)
		"character_skin":
			return String(profile.default_character_skin_id) == String(item.asset_id)
		"bubble":
			return String(profile.default_bubble_style_id) == String(item.asset_id)
		"bubble_skin":
			return String(profile.default_bubble_skin_id) == String(item.asset_id)
		"title":
			return "title_id" in profile and String(profile.title_id) == String(item.asset_id)
		"avatar":
			return "avatar_id" in profile and String(profile.avatar_id) == String(item.asset_id)
	return false
