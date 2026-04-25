class_name BattleHudResourceBinder
extends RefCounted

const BattleHudAssetIdsScript = preload("res://presentation/battle/hud/battle_hud_asset_ids.gd")


func bind_panel_assets(panel_nodes: Dictionary) -> Dictionary:
	var bound_assets: Dictionary = {}
	var panel_assets: Dictionary = BattleHudAssetIdsScript.panel_asset_map()
	for panel_name in panel_assets.keys():
		var panel_node: Node = panel_nodes.get(panel_name, null)
		if panel_node == null:
			continue
		var asset_id := String(panel_assets[panel_name])
		panel_node.set_meta("ui_asset_id", asset_id)
		bound_assets[panel_name] = asset_id
	return bound_assets
