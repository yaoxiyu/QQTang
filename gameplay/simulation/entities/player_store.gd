# 角色：
# 玩家存储管理器，管理所有玩家实体
#
# 读写边界：
# - 只在 SimulationRunner/初始化时被写入
# - 可在任何系统中被读取（通过 get()）
#
# 禁止事项：
# - 不得在此文件中写规则逻辑

class_name PlayerStore
extends RefCounted

# 玩家状态数组
var _states: Array[PlayerState] = []

# 生成号数组（用于实体重生机制）
var _generations: Array[int] = []

# 活跃玩家ID列表
var active_ids: Array[int] = []

# 下一个实体ID
var next_entity_id: int = 1

# ====================
# 基础方法
# ====================

# 获取玩家数量
func size() -> int:
	return _states.size()

# 检查玩家是否存在
func has(player_id: int) -> bool:
	return player_id >= 0 and player_id < _states.size() and _states[player_id] != null

# 获取玩家状态（只读）
func get_player(player_id: int) -> PlayerState:
	if player_id < 0 or player_id >= _states.size():
		return null
	return _states[player_id]

# 获取玩家状态（可写）
func get_player_mut(player_id: int) -> PlayerState:
	if player_id < 0 or player_id >= _states.size():
		return null
	return _states[player_id]

# 获取活跃玩家ID列表
func get_active_ids() -> Array[int]:
	return active_ids.duplicate()

# ====================
# 管理方法
# ====================

# 添加玩家
func add_player(
	p_player_slot: int,
	p_team_id: int,
	p_cell_x: int = 0,
	p_cell_y: int = 0
) -> int:
	var player := PlayerState.new()

	# 初始化基本属性
	player.entity_id = next_entity_id
	player.generation = 1
	player.player_slot = p_player_slot
	player.team_id = p_team_id
	player.cell_x = p_cell_x
	player.cell_y = p_cell_y
	player.alive = true
	player.life_state = PlayerState.LifeState.NORMAL
	player.bomb_available = player.bomb_capacity

	# 扩展数组
	while _states.size() <= next_entity_id:
		_states.append(null)
		_generations.append(0)

	_states[next_entity_id] = player
	_generations[next_entity_id] = 1
	active_ids.append(next_entity_id)

	next_entity_id += 1
	return player.entity_id


func restore_player_from_snapshot(data: Dictionary) -> int:
	var entity_id := int(data.get("entity_id", -1))
	if entity_id < 0:
		return -1
	var player := PlayerState.new()
	player.entity_id = entity_id
	player.generation = int(data.get("generation", 1))
	player.player_slot = int(data.get("player_slot", 0))
	player.team_id = int(data.get("team_id", 0))
	player.alive = bool(data.get("alive", true))
	player.life_state = int(data.get("life_state", PlayerState.LifeState.NORMAL))
	player.cell_x = int(data.get("cell_x", 0))
	player.cell_y = int(data.get("cell_y", 0))
	player.offset_x = int(data.get("offset_x", 0))
	player.offset_y = int(data.get("offset_y", 0))
	player.last_place_bubble_pressed = bool(data.get("last_place_bubble_pressed", false))
	player.move_phase_ticks = int(data.get("move_phase_ticks", 0))
	player.facing = int(data.get("facing", player.facing))
	player.move_state = int(data.get("move_state", player.move_state))
	player.last_non_zero_move_x = int(data.get("last_non_zero_move_x", 0))
	player.last_non_zero_move_y = int(data.get("last_non_zero_move_y", 0))
	player.speed_level = int(data.get("speed_level", player.speed_level))
	player.bomb_capacity = int(data.get("bomb_capacity", player.bomb_capacity))
	player.bomb_available = int(data.get("bomb_available", player.bomb_available))
	player.bomb_range = int(data.get("bomb_range", player.bomb_range))
	player.bomb_fuse_ticks = int(data.get("bomb_fuse_ticks", player.bomb_fuse_ticks))
	player.has_kick = bool(data.get("has_kick", false))
	player.has_push = bool(data.get("has_push", false))
	player.has_remote = bool(data.get("has_remote", false))
	player.has_pierce = bool(data.get("has_pierce", false))
	player.can_cross_own_bubble = bool(data.get("can_cross_own_bubble", false))
	player.shield_ticks = int(data.get("shield_ticks", 0))
	player.invincible_ticks = int(data.get("invincible_ticks", 0))
	player.stun_ticks = int(data.get("stun_ticks", 0))
	player.respawn_ticks = int(data.get("respawn_ticks", 0))
	player.trap_bubble_id = int(data.get("trap_bubble_id", -1))
	player.last_damage_from_player_id = int(data.get("last_damage_from_player_id", -1))
	player.kills = int(data.get("kills", 0))
	player.deaths = int(data.get("deaths", 0))
	player.score = int(data.get("score", 0))
	player.controller_type = int(data.get("controller_type", player.controller_type))

	while _states.size() <= entity_id:
		_states.append(null)
		_generations.append(0)

	_states[entity_id] = player
	_generations[entity_id] = player.generation
	if player.alive and not active_ids.has(entity_id):
		active_ids.append(entity_id)
	active_ids.sort()
	next_entity_id = max(next_entity_id, entity_id + 1)
	return entity_id

# 更新玩家状态
func update_player(player: PlayerState) -> void:
	if player.entity_id >= 0 and player.entity_id < _states.size():
		_states[player.entity_id] = player

# 标记玩家死亡（先标记，不立即删除）
func mark_player_dead(player_id: int) -> void:
	if player_id < 0 or player_id >= _states.size():
		return
	var player := _states[player_id]
	if player != null:
		player.alive = false
		player.life_state = PlayerState.LifeState.DEAD
		# 从活跃列表移除
		if player_id in active_ids:
			active_ids.remove_at(active_ids.find(player_id))

# 复活玩家
func revive_player(
	player_id: int,
	p_cell_x: int,
	p_cell_y: int
) -> void:
	if player_id < 0 or player_id >= _states.size():
		return
	var player := _states[player_id]
	if player != null:
		player.alive = true
		player.life_state = PlayerState.LifeState.NORMAL
		player.cell_x = p_cell_x
		player.cell_y = p_cell_y
		player.respawn_ticks = 0
		player.bomb_available = player.bomb_capacity
		if not (player_id in active_ids):
			active_ids.append(player_id)

# 清空所有玩家
func clear() -> void:
	_states.clear()
	_generations.clear()
	active_ids.clear()
	next_entity_id = 1

# ====================
# 遍历方法
# ====================

# 遍历所有活跃玩家
func for_each_active(callback : Callable) -> void:
	for player_id in active_ids:
		var player := _states[player_id]
		if player != null and player.alive:
			callback.call(player)
