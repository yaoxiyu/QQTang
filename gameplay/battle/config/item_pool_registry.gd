class_name ItemPoolRegistry
extends RefCounted

# 默认道具池 — 所有地图未配置专用池时使用此配置
const DEFAULT_POOL := {
	"description": "默认固定道具池",
	"airplane_interval_sec": 10,
	"entries": [
		{"battle_item_id": "1", "count": 8},
		{"battle_item_id": "2", "count": 6},
		{"battle_item_id": "3", "count": 6},
		{"battle_item_id": "6", "count": 2},
		{"battle_item_id": "7", "count": 2},
		{"battle_item_id": "8", "count": 2},
	],
}

# 地图专用池 — key 为 pool_id，value 为覆盖 DEFAULT_POOL 的配置
const MAP_SPECIFIC_POOLS := {
	# 示例：pool_id = "map_match01" 有专用配置时在此添加
	# "map_match01": {
	# 	"description": "match01 专用道具池",
	# 	"airplane_interval_sec": 8,
	# 	"entries": [
	# 		{"battle_item_id": "1", "count": 10},
	# 		{"battle_item_id": "2", "count": 8},
	# 	],
	# },
}


static func get_pool(pool_id: String) -> Dictionary:
	var base := DEFAULT_POOL.duplicate(true)
	base["entries"] = base["entries"].duplicate(true)
	if pool_id.is_empty() or pool_id == "default_items":
		return base
	var override: Dictionary = MAP_SPECIFIC_POOLS.get(pool_id, {})
	if override.is_empty():
		return base
	if override.has("airplane_interval_sec"):
		base["airplane_interval_sec"] = int(override["airplane_interval_sec"])
	var override_entries: Array = override.get("entries", [])
	if override_entries.is_empty():
		return base
	var merged: Dictionary = {}
	for entry in base["entries"]:
		merged[String(entry.get("battle_item_id", ""))] = int(entry.get("count", 0))
	for entry in override_entries:
		var bid := String(entry.get("battle_item_id", ""))
		merged[bid] = int(entry.get("count", 0))
	var result_entries: Array[Dictionary] = []
	for bid in merged.keys():
		if merged[bid] > 0:
			result_entries.append({"battle_item_id": bid, "count": merged[bid]})
	base["entries"] = result_entries
	return base


static func has_pool(pool_id: String) -> bool:
	if pool_id.is_empty() or pool_id == "default_items":
		return true
	return MAP_SPECIFIC_POOLS.has(pool_id)
