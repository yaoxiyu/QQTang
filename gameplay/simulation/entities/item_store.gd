# 角色：
# 道具存储管理器，管理所有道具实体
#
# 读写边界：
# - 只在 ItemSpawnSystem/ ItemPickupSystem 中被写入
# - 可在任何系统中被读取（通过 get()）
#
# 禁止事项：
# - 不得在此文件中写规则逻辑

class_name ItemStore
extends RefCounted

const ItemDebugLogScript = preload("res://app/logging/item_debug_log.gd")

# 道具状态数组
var _states: Array[ItemState] = []

# 活跃道具ID列表
var active_ids: Array[int] = []

# 空闲ID列表（用于复用）
var free_ids: Array[int] = []

# 下一个实体ID
var next_entity_id: int = 1

# ====================
# 基础方法
# ====================

# 获取道具数量
func size() -> int:
	return _states.size()

# 检查道具是否存在
func has(item_id: int) -> bool:
	return item_id >= 0 and item_id < _states.size() and _states[item_id] != null

# 获取道具状态（只读）
func get_item(item_id: int) -> ItemState:
	if not has(item_id):
		return null
	return _states[item_id]

# 获取道具状态（可写）
func get_item_mut(item_id: int) -> ItemState:
	if not has(item_id):
		return null
	return _states[item_id]

# ====================
# 管理方法
# ====================

# 生成新的道具ID
func _allocate_id() -> int:
	if free_ids.size() > 0:
		return free_ids.pop_back()

	var id := next_entity_id
	next_entity_id += 1
	return id

# 生成道具
func spawn_item(
	p_item_type: int,
	p_cell_x: int,
	p_cell_y: int,
	p_pickup_delay_ticks: int = 0,
	p_battle_item_id: String = "",
	p_pool_category: String = ""
) -> int:
	var item := ItemState.new()

	item.entity_id = _allocate_id()
	item.generation = 1
	item.item_type = p_item_type
	item.battle_item_id = p_battle_item_id
	item.pool_category = p_pool_category
	item.cell_x = p_cell_x
	item.cell_y = p_cell_y
	item.spawn_tick = 0  # 由系统设置
	item.pickup_delay_ticks = p_pickup_delay_ticks
	item.alive = true
	item.visible = true

	ItemDebugLogScript.write("[ITEM_POS] spawn_item eid=%d battle_item=%s pos=(%d,%d) pool_cat=%s" % [item.entity_id, p_battle_item_id, p_cell_x, p_cell_y, p_pool_category])

	# 扩展数组
	while _states.size() <= item.entity_id:
		_states.append(null)

	_states[item.entity_id] = item
	active_ids.append(item.entity_id)

	return item.entity_id


func restore_item_from_snapshot(data: Dictionary) -> int:
	var entity_id := int(data.get("entity_id", -1))
	if entity_id < 0:
		return -1
	var item := ItemState.new()
	item.entity_id = entity_id
	item.generation = int(data.get("generation", 1))
	item.alive = bool(data.get("alive", true))
	item.item_type = int(data.get("item_type", 0))
	item.battle_item_id = String(data.get("battle_item_id", ""))
	item.pool_category = String(data.get("pool_category", ""))
	item.cell_x = int(data.get("cell_x", 0))
	item.cell_y = int(data.get("cell_y", 0))
	item.spawn_tick = int(data.get("spawn_tick", 0))
	item.pickup_delay_ticks = int(data.get("pickup_delay_ticks", 0))
	item.visible = bool(data.get("visible", true))

	ItemDebugLogScript.write("[ITEM_POS] restore_snapshot eid=%d battle_item=%s pos=(%d,%d) data_keys=%s" % [entity_id, item.battle_item_id, item.cell_x, item.cell_y, str(data.keys())])

	while _states.size() <= entity_id:
		_states.append(null)

	_states[entity_id] = item
	if item.alive and not active_ids.has(entity_id):
		active_ids.append(entity_id)
	active_ids.sort()
	next_entity_id = max(next_entity_id, entity_id + 1)
	free_ids.erase(entity_id)
	return entity_id

# 标记道具销毁
func despawn_item(item_id: int) -> void:
	if not has(item_id):
		return
	var item := _states[item_id]
	if item != null:
		item.alive = false
		# 从活跃列表移除
		if item_id in active_ids:
			active_ids.remove_at(active_ids.find(item_id))
		# 加入空闲列表
		free_ids.append(item_id)

# 更新道具状态
func update_item(item: ItemState) -> void:
	if item.entity_id >= 0 and item.entity_id < _states.size():
		_states[item.entity_id] = item

# 清空所有道具
func clear() -> void:
	_states.clear()
	active_ids.clear()
	free_ids.clear()
	next_entity_id = 1

# ====================
# 遍历方法
# ====================

# 遍历所有活跃道具
func for_each_active(callback : Callable) -> void:
	for item_id in active_ids:
		var item := _states[item_id]
		if item != null and item.alive:
			callback.call(item)
