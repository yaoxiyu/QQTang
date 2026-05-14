extends RefCounted

# 方块→道具 分配表（开战时确定，快照捕获）
var block_assignments: Dictionary = {}  # "x,y" → {"battle_item_id": String, "pool_category": String}

# 被装饰性地表元素覆盖的格子（>1x1 的表现层方块），不可空投（快照捕获）
var blocked_drop_cells: Dictionary = {}  # "x,y" → true

# 回收池 — 被炸/死亡返回的道具，等待飞机空投（快照捕获）
var recycle_pool: Dictionary = {}  # battle_item_id → count

# 飞机计时器（快照捕获）
var airplane_timer_ticks: int = 0
var airplane_interval_ticks: int = 300  # 10s * 30 tick/s

# 飞机实体状态（快照捕获）
var airplane_active: bool = false
var airplane_x: float = 0.0  # 当前 x 坐标（浮点，支持平滑移动）
var airplane_y: int = 0      # 飞行所在行
var airplane_drop_cooldown: int = 0  # 空投冷却 tick


func has_assignment(cell_x: int, cell_y: int) -> bool:
	return block_assignments.has("%d,%d" % [cell_x, cell_y])


func consume_assignment(cell_x: int, cell_y: int) -> Dictionary:
	var key := "%d,%d" % [cell_x, cell_y]
	if not block_assignments.has(key):
		return {}
	var value: Dictionary = block_assignments[key]
	block_assignments.erase(key)
	return value


func add_to_recycle(battle_item_id: String, count: int = 1) -> void:
	if battle_item_id.is_empty() or count <= 0:
		return
	var current := int(recycle_pool.get(battle_item_id, 0))
	recycle_pool[battle_item_id] = current + count


func consume_from_recycle(count: int) -> Array[String]:
	if count <= 0:
		return []
	var result: Array[String] = []
	var bids: Array[String] = []
	for bid in recycle_pool.keys():
		bids.append(bid)
	if bids.is_empty():
		return result
	for bid in bids:
		var available := int(recycle_pool.get(bid, 0))
		if available <= 0:
			continue
		for _i in range(available):
			result.append(bid)
			if result.size() >= count:
				for j in range(result.size()):
					var taken_bid := result[j]
					recycle_pool[taken_bid] = int(recycle_pool.get(taken_bid, 0)) - 1
					if int(recycle_pool.get(taken_bid, 0)) <= 0:
						recycle_pool.erase(taken_bid)
				return result
	for j in range(result.size()):
		var taken_bid := result[j]
		recycle_pool[taken_bid] = int(recycle_pool.get(taken_bid, 0)) - 1
		if int(recycle_pool.get(taken_bid, 0)) <= 0:
			recycle_pool.erase(taken_bid)
	return result


func capture_snapshot() -> Dictionary:
	return {
		"block_assignments": block_assignments.duplicate(true),
		"recycle_pool": recycle_pool.duplicate(true),
		"airplane_timer_ticks": airplane_timer_ticks,
		"airplane_interval_ticks": airplane_interval_ticks,
		"airplane_active": airplane_active,
		"airplane_x": airplane_x,
		"airplane_y": airplane_y,
		"airplane_drop_cooldown": airplane_drop_cooldown,
		"blocked_drop_cells": blocked_drop_cells.duplicate(true),
	}


func restore_from_snapshot(data: Dictionary) -> void:
	block_assignments = data.get("block_assignments", {}).duplicate(true)
	recycle_pool = data.get("recycle_pool", {}).duplicate(true)
	airplane_timer_ticks = int(data.get("airplane_timer_ticks", 0))
	airplane_interval_ticks = int(data.get("airplane_interval_ticks", 300))
	airplane_active = bool(data.get("airplane_active", false))
	airplane_x = float(data.get("airplane_x", 0.0))
	airplane_y = int(data.get("airplane_y", 0))
	airplane_drop_cooldown = int(data.get("airplane_drop_cooldown", 0))
	blocked_drop_cells = data.get("blocked_drop_cells", {}).duplicate(true)
