# 角色：
# 仿真索引结构，用于快速查询
#
# 读写边界：
# - 只在 SimWorld.step() 中被写入（rebuild）
# - 可在任何查询系统中被读取
#
# 禁止事项：
# - 不得在此文件中写规则逻辑

class_name SimIndexes
extends RefCounted

const PlayerLocator = preload("res://gameplay/simulation/movement/player_locator.gd")

# ====================
# 格子索引
# ====================

# 每个格子上的玩家列表（支持多玩家同格）
# 使用一维数组索引：players_by_cell[to_cell_index(x, y)] = Array[player_id]
var players_by_cell: Array = []

# 每个格子上的泡泡ID（一个格子最多一个泡泡）
# 使用一维数组索引：bubbles_by_cell[to_cell_index(x, y)] = bubble_id
var bubbles_by_cell: Array = []

# 每个格子上的道具ID（一个格子最多一个道具）
# 使用一维数组索引：items_by_cell[to_cell_index(x, y)] = item_id
var items_by_cell: Array = []

# ====================
# 活跃实体列表
# ====================

# 活跃玩家ID列表（只包含alive=true的玩家）
var living_player_ids: Array[int] = []

# 活跃泡泡ID列表
var active_bubble_ids: Array[int] = []

# 活跃道具ID列表
var active_item_ids: Array[int] = []

# ====================
# 初始化
# ====================

# 初始化数组（根据 gridSize）
func initialize(grid_size: int) -> void:
	players_by_cell.resize(grid_size)
	bubbles_by_cell.resize(grid_size)
	items_by_cell.resize(grid_size)

	for i in range(grid_size):
		players_by_cell[i] = []
		bubbles_by_cell[i] = -1
		items_by_cell[i] = -1

# ====================
# 核心方法
# ====================

# 清空所有索引（安全版本，避免未初始化错误）
func clear() -> void:
	if players_by_cell.size() == 0:
		return

	for i in range(players_by_cell.size()):
		players_by_cell[i].clear()
		bubbles_by_cell[i] = -1
		items_by_cell[i] = -1

	living_player_ids.clear()
	active_bubble_ids.clear()
	active_item_ids.clear()

# 从状态中重建索引
func rebuild_from_state(state: SimState) -> void:
	var grid_size = state.grid.width * state.grid.height
	if players_by_cell.size() != grid_size:
		initialize(grid_size)
	else:
		clear()

	# 重建玩家索引
	for player_id in state.players.active_ids:
		var player := state.players.get_player(player_id)
		if player != null and player.alive:
			living_player_ids.append(player_id)

			var foot_cell := PlayerLocator.get_foot_cell(player)
			var cell_idx = state.grid.to_cell_index(foot_cell.x, foot_cell.y)
			if cell_idx >= 0 and cell_idx < players_by_cell.size():
				players_by_cell[cell_idx].append(player_id)

	# 重建泡泡索引
	for bubble_id in state.bubbles.active_ids:
		var bubble := state.bubbles.get_bubble(bubble_id)
		if bubble != null and bubble.alive:
			active_bubble_ids.append(bubble_id)

			var cell_idx = state.grid.to_cell_index(bubble.cell_x, bubble.cell_y)
			if cell_idx >= 0 and cell_idx < bubbles_by_cell.size():
				bubbles_by_cell[cell_idx] = bubble_id

	# 重建道具索引
	for item_id in state.items.active_ids:
		var item := state.items.get_item(item_id)
		if item != null and item.alive:
			active_item_ids.append(item_id)

			var cell_idx = state.grid.to_cell_index(item.cell_x, item.cell_y)
			if cell_idx >= 0 and cell_idx < items_by_cell.size():
				items_by_cell[cell_idx] = item_id
