# 角色：
# 泡泡存储管理器，管理所有泡泡实体
#
# 读写边界：
# - 只在 BubblePlacementSystem/ ExplosionResolveSystem 中被写入
# - 可在任何系统中被读取（通过 get()）
#
# 禁止事项：
# - 不得在此文件中写规则逻辑

class_name BubbleStore
extends RefCounted

# 泡泡状态数组
var _states: Array[BubbleState] = []

# 生成号数组
var _generations: Array[int] = []

# 活跃泡泡ID列表
var active_ids: Array[int] = []

# 空闲ID列表（用于复用）
var free_ids: Array[int] = []

# 下一个实体ID
var next_entity_id: int = 1

# ====================
# 基础方法
# ====================

# 获取泡泡数量
func size() -> int:
	return _states.size()

# 检查泡泡是否存在
func has(bubble_id: int) -> bool:
	return bubble_id >= 0 and bubble_id < _states.size() and _states[bubble_id] != null

# 获取泡泡状态（只读）
func get_bubble(bubble_id: int) -> BubbleState:
	if not has(bubble_id):
		return null
	return _states[bubble_id]

# 获取泡泡状态（可写）
func get_bubble_mut(bubble_id: int) -> BubbleState:
	if not has(bubble_id):
		return null
	return _states[bubble_id]

# ====================
# 管理方法
# ====================

# 生成新的泡泡ID
func _allocate_id() -> int:
	if free_ids.size() > 0:
		return free_ids.pop_back()

	var id := next_entity_id
	next_entity_id += 1
	return id

# 生成泡泡
func spawn_bubble(
	p_owner_player_id: int,
	p_cell_x: int,
	p_cell_y: int,
	p_range: int = 1,
	p_explode_tick: int = 60
) -> int:
	var bubble := BubbleState.new()

	bubble.entity_id = _allocate_id()
	bubble.generation = 1
	bubble.owner_player_id = p_owner_player_id
	bubble.cell_x = p_cell_x
	bubble.cell_y = p_cell_y
	bubble.spawn_tick = 0  # 由系统设置
	bubble.explode_tick = p_explode_tick
	bubble.bubble_range = p_range
	bubble.alive = true
	bubble.moving_state = BubbleState.MovingState.STATIC

	# 扩展数组
	while _states.size() <= bubble.entity_id:
		_states.append(null)
		_generations.append(0)

	_states[bubble.entity_id] = bubble
	_generations[bubble.entity_id] = 1
	active_ids.append(bubble.entity_id)

	return bubble.entity_id

# 标记泡泡销毁
func despawn_bubble(bubble_id: int) -> void:
	if not has(bubble_id):
		return
	var bubble := _states[bubble_id]
	if bubble != null:
		bubble.alive = false
		# 从活跃列表移除
		if bubble_id in active_ids:
			active_ids.remove_at(active_ids.find(bubble_id))
		# 加入空闲列表
		free_ids.append(bubble_id)

# 更新泡泡状态
func update_bubble(bubble: BubbleState) -> void:
	if bubble.entity_id >= 0 and bubble.entity_id < _states.size():
		_states[bubble.entity_id] = bubble

# 清空所有泡泡
func clear() -> void:
	_states.clear()
	_generations.clear()
	active_ids.clear()
	free_ids.clear()
	next_entity_id = 1

# ====================
# 遍历方法
# ====================

# 遍历所有活跃泡泡
func for_each_active(callback: Callable) -> void:
	for bubble_id in active_ids:
		var bubble := _states[bubble_id]
		if bubble != null and bubble.alive:
			callback.call(bubble)
