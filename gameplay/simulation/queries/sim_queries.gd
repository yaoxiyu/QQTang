# 角色：
# 查询门面，为系统提供只读查询接口
#
# 读写边界：
# - 只读，不写入任何状态
# - 所有查询都从 SimState 中读取
#
# 禁止事项：
# - 禁止写状态
# - 禁止 spawn/despawn 实体
# - 禁止依赖 Presentation 层

class_name SimQueries
extends RefCounted

const RailConstraint = preload("res://gameplay/simulation/movement/rail_constraint.gd")
const GridMotionMath = preload("res://gameplay/simulation/movement/grid_motion_math.gd")

# ====================
# 依赖注入
# ====================

# 持有 SimState 引用以进行查询
var _state: SimState = null

func set_state(state: SimState) -> void:
	_state = state

# ====================
# 辅助方法
# ====================

# 边界检查
func is_in_bounds(cell_x: int, cell_y: int) -> bool:
	if _state == null:
		return false
	return _state.grid.is_in_bounds(cell_x, cell_y)

# 计算格子索引
func to_cell_index(cell_x: int, cell_y: int) -> int:
	if _state == null:
		return -1
	return _state.grid.to_cell_index(cell_x, cell_y)

# ====================
# 实体获取
# ====================

# 获取玩家状态
func get_player(player_id: int) -> PlayerState:
	if _state == null:
		return null
	return _state.players.get_player(player_id)

# 获取泡泡状态
func get_bubble(bubble_id: int) -> BubbleState:
	if _state == null:
		return null
	return _state.bubbles.get_bubble(bubble_id)

# 获取道具状态
func get_item(item_id: int) -> ItemState:
	if _state == null:
		return null
	return _state.items.get_item(item_id)

# ====================
# 格子查询
# ====================

# 获取格子上的玩家列表
# 注意：返回动态数组，需要类型转换
func get_players_at(cell_x: int, cell_y: int) -> Array:
	if not is_in_bounds(cell_x, cell_y):
		return []
	var cell_idx = to_cell_index(cell_x, cell_y)
	return _state.indexes.players_by_cell[cell_idx].duplicate()

# 获取格子上的泡泡ID
func get_bubble_at(cell_x: int, cell_y: int) -> int:
	if not is_in_bounds(cell_x, cell_y):
		return -1
	var cell_idx = to_cell_index(cell_x, cell_y)
	return _state.indexes.bubbles_by_cell[cell_idx]

# 获取格子上的道具ID
func get_item_at(cell_x: int, cell_y: int) -> int:
	if not is_in_bounds(cell_x, cell_y):
		return -1
	var cell_idx = to_cell_index(cell_x, cell_y)
	return _state.indexes.items_by_cell[cell_idx]

# 检查格子是否有 explosion_flags
func has_explosion_at(cell_x: int, cell_y: int) -> bool:
	if not is_in_bounds(cell_x, cell_y):
		return false
	var cell = _state.grid.get_dynamic_cell(cell_x, cell_y)
	return cell.explosion_flags > 0

# ====================
# 阻挡查询
# ====================

# 检查是否硬阻挡（墙等）
func is_hard_blocked(cell_x: int, cell_y: int) -> bool:
	if not is_in_bounds(cell_x, cell_y):
		return true
	var cell = _state.grid.get_static_cell(cell_x, cell_y)
	return (cell.tile_flags & TileConstants.TILE_BLOCK_MOVE) != 0

# 检查是否阻挡爆炸
func is_explosion_blocked(cell_x: int, cell_y: int) -> bool:
	if not is_in_bounds(cell_x, cell_y):
		return true
	var cell = _state.grid.get_static_cell(cell_x, cell_y)
	return (cell.tile_flags & TileConstants.TILE_BLOCK_EXPLOSION) != 0

# 检查是否可破坏
func is_breakable(cell_x: int, cell_y: int) -> bool:
	if not is_in_bounds(cell_x, cell_y):
		return false
	var cell = _state.grid.get_static_cell(cell_x, cell_y)
	return (cell.tile_flags & TileConstants.TILE_BREAKABLE) != 0

# 检查是否是出生点
func is_spawn(cell_x: int, cell_y: int) -> bool:
	if not is_in_bounds(cell_x, cell_y):
		return false
	var cell = _state.grid.get_static_cell(cell_x, cell_y)
	return (cell.tile_flags & TileConstants.TILE_IS_SPAWN) != 0

# 检查是否可掉落道具
func can_spawn_item(cell_x: int, cell_y: int) -> bool:
	if not is_in_bounds(cell_x, cell_y):
		return false
	var cell = _state.grid.get_static_cell(cell_x, cell_y)
	return (cell.tile_flags & TileConstants.TILE_CAN_SPAWN_ITEM) != 0

# 检查玩家是否被阻挡
func is_move_blocked_for_player(player_id: int, cell_x: int, cell_y: int) -> bool:
	# 检查硬阻挡
	if is_hard_blocked(cell_x, cell_y):
		return true

	# 检查是否有泡泡（玩家不能进入有泡泡的格子）
	var bubble_id := get_bubble_at(cell_x, cell_y)
	if bubble_id != -1 and _is_bubble_blocking_for_player(player_id, bubble_id):
		return true

	return false


func is_lane_blocked_for_player(player_id: int, cell_x: int, cell_y: int) -> bool:
	if player_id < 0:
		return true

	if is_hard_blocked(cell_x, cell_y):
		return true

	var bubble_id := get_bubble_at(cell_x, cell_y)
	return bubble_id != -1 and _is_bubble_blocking_for_player(player_id, bubble_id)


func is_transition_blocked_for_player(
	player_id: int,
	from_x: int,
	from_y: int,
	to_x: int,
	to_y: int
) -> bool:
	if from_x == to_x and from_y == to_y:
		return false

	return is_move_blocked_for_player(player_id, to_x, to_y)


func get_player_rail_constraint(player_id: int, cell_x: int, cell_y: int) -> int:
	var up_blocked := is_lane_blocked_for_player(player_id, cell_x, cell_y - 1)
	var down_blocked := is_lane_blocked_for_player(player_id, cell_x, cell_y + 1)
	var left_blocked := is_lane_blocked_for_player(player_id, cell_x - 1, cell_y)
	var right_blocked := is_lane_blocked_for_player(player_id, cell_x + 1, cell_y)
	return RailConstraint.resolve_from_neighbors(
		up_blocked,
		down_blocked,
		left_blocked,
		right_blocked
	)


func is_player_overlapping_bubble(player_id: int, bubble_id: int) -> bool:
	var player := get_player(player_id)
	var bubble := get_bubble(bubble_id)
	if player == null or bubble == null or not player.alive or not bubble.alive:
		return false

	var player_abs_x := GridMotionMath.to_abs_x(player.cell_x, player.offset_x)
	var player_abs_y := GridMotionMath.to_abs_y(player.cell_y, player.offset_y)
	var bubble_abs_x := GridMotionMath.get_cell_center_abs_x(bubble.cell_x)
	var bubble_abs_y := GridMotionMath.get_cell_center_abs_y(bubble.cell_y)
	return abs(player_abs_x - bubble_abs_x) < GridMotionMath.CELL_UNITS and abs(player_abs_y - bubble_abs_y) < GridMotionMath.CELL_UNITS


func _is_bubble_blocking_for_player(player_id: int, bubble_id: int) -> bool:
	var bubble := get_bubble(bubble_id)
	if bubble == null or not bubble.alive:
		return false
	return not bubble.ignore_player_ids.has(player_id)

# ====================
# 游戏状态查询
# ====================

# 判断游戏是否进行中
func is_match_playing() -> bool:
	if _state == null:
		return false
	return _state.match_state.phase == MatchState.Phase.PLAYING

# 获取存活玩家数
func get_alive_player_count() -> int:
	if _state == null:
		return 0
	return _state.indexes.living_player_ids.size()

# 获取存活队伍数
func get_alive_team_count() -> int:
	var teams: Dictionary = {}
	for player_id in _state.indexes.living_player_ids:
		var player = get_player(player_id)
		if player != null:
			teams[player.team_id] = true
	return teams.size()
