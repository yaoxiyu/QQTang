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
const MovementTuning = preload("res://gameplay/simulation/movement/movement_tuning.gd")
const BubblePassPhaseScript = preload("res://gameplay/simulation/entities/bubble_pass_phase.gd")
const BubblePassPhaseHelper = preload("res://gameplay/simulation/movement/bubble_pass_phase_helper.gd")

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
	return (cell.tile_flags & TileConstants.TILE_BLOCK_MOVE) != 0 and cell.movement_pass_mask == TileConstants.PASS_NONE


func is_transition_tile_blocked(from_x: int, from_y: int, to_x: int, to_y: int) -> bool:
	if not is_in_bounds(from_x, from_y) or not is_in_bounds(to_x, to_y):
		return true
	var dx := to_x - from_x
	var dy := to_y - from_y
	var from_bit := _pass_bit_from_delta(dx, dy)
	if from_bit == 0:
		return true
	var to_bit := _pass_bit_from_delta(-dx, -dy)
	var from_cell := _state.grid.get_static_cell(from_x, from_y)
	var to_cell := _state.grid.get_static_cell(to_x, to_y)
	if (from_cell.movement_pass_mask & from_bit) == 0:
		return true
	if (to_cell.movement_pass_mask & to_bit) == 0:
		return true
	return false

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


func can_place_bubble_at(cell_x: int, cell_y: int) -> bool:
	if not is_in_bounds(cell_x, cell_y):
		return false
	var cell = _state.grid.get_static_cell(cell_x, cell_y)
	return bool(cell.allow_place_bubble)

# 检查玩家是否被阻挡（cell 级薄包装：用目标格中心当作候选位置转发到 *_at_pos 版本）
func is_move_blocked_for_player(player_id: int, cell_x: int, cell_y: int) -> bool:
	var candidate_abs_x := GridMotionMath.get_cell_center_abs_x(cell_x)
	var candidate_abs_y := GridMotionMath.get_cell_center_abs_y(cell_y)
	return is_move_blocked_for_player_at_pos(player_id, cell_x, cell_y, candidate_abs_x, candidate_abs_y)


# 带候选绝对位置的阻挡判定，用于运动子步：tile 硬阻挡 + 泡泡 phase 判定。
func is_move_blocked_for_player_at_pos(
	player_id: int,
	cell_x: int,
	cell_y: int,
	candidate_abs_x: int,
	candidate_abs_y: int
) -> bool:
	if is_hard_blocked(cell_x, cell_y):
		return true
	var bubble_id := get_bubble_at(cell_x, cell_y)
	if bubble_id == -1:
		return false
	return is_bubble_blocking_at_pos(player_id, bubble_id, candidate_abs_x, candidate_abs_y)


func is_lane_blocked_for_player(player_id: int, cell_x: int, cell_y: int) -> bool:
	if player_id < 0:
		return true

	var player := get_player(player_id)
	if player == null:
		return true
	if is_transition_tile_blocked(player.cell_x, player.cell_y, cell_x, cell_y):
		return true

	var bubble_id := get_bubble_at(cell_x, cell_y)
	if bubble_id == -1:
		return false
	# 轨道判定本质是"玩家若去该邻格中心会不会被挡"——用邻格中心作为候选位置即可。
	var candidate_abs_x := GridMotionMath.get_cell_center_abs_x(cell_x)
	var candidate_abs_y := GridMotionMath.get_cell_center_abs_y(cell_y)
	return is_bubble_blocking_at_pos(player_id, bubble_id, candidate_abs_x, candidate_abs_y)


func is_transition_blocked_for_player(
	player_id: int,
	from_x: int,
	from_y: int,
	to_x: int,
	to_y: int
) -> bool:
	if from_x == to_x and from_y == to_y:
		return is_move_blocked_for_player(player_id, to_x, to_y)

	return is_move_blocked_for_player(player_id, to_x, to_y)


# 带候选绝对位置的 transition 判定，供 MovementSystem 子步使用以支持 phase B 的细粒度约束。
func is_transition_blocked_for_player_at_pos(
	player_id: int,
	from_x: int,
	from_y: int,
	to_x: int,
	to_y: int,
	candidate_abs_x: int,
	candidate_abs_y: int
) -> bool:
	if from_x == to_x and from_y == to_y:
		return is_move_blocked_for_player_at_pos(player_id, to_x, to_y, candidate_abs_x, candidate_abs_y)
	if is_transition_tile_blocked(from_x, from_y, to_x, to_y):
		return true
	return is_move_blocked_for_player_at_pos(player_id, to_x, to_y, candidate_abs_x, candidate_abs_y)


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
	var center := resolve_bubble_reference_center(bubble, Vector2i(player_abs_x, player_abs_y))
	return abs(player_abs_x - center.x) < GridMotionMath.CELL_UNITS \
		and abs(player_abs_y - center.y) < GridMotionMath.CELL_UNITS


# 根据 MovementTuning.BUBBLE_OVERLAP_CENTER_MODE 选择泡泡的参考中心：
#   0 = bubble.cell_x/cell_y 单格中心（默认，与历史行为一致）
#   1 = footprint 内距玩家位置最近的格中心
func resolve_bubble_reference_center(bubble: BubbleState, player_abs_pos: Vector2i) -> Vector2i:
	if bubble == null:
		return Vector2i.ZERO
	if MovementTuning.bubble_overlap_center_mode() == 0:
		return Vector2i(
			GridMotionMath.get_cell_center_abs_x(bubble.cell_x),
			GridMotionMath.get_cell_center_abs_y(bubble.cell_y)
		)
	var best_center := Vector2i(
		GridMotionMath.get_cell_center_abs_x(bubble.cell_x),
		GridMotionMath.get_cell_center_abs_y(bubble.cell_y)
	)
	var best_dist := absi(player_abs_pos.x - best_center.x) + absi(player_abs_pos.y - best_center.y)
	for cell in bubble.get_footprint_cells():
		var c := Vector2i(
			GridMotionMath.get_cell_center_abs_x(cell.x),
			GridMotionMath.get_cell_center_abs_y(cell.y)
		)
		var d := absi(player_abs_pos.x - c.x) + absi(player_abs_pos.y - c.y)
		if d < best_dist:
			best_dist = d
			best_center = c
	return best_center


# 给 MovementSystem 子步使用的轴向限位查询：当玩家沿 (move_x, move_y) 进入 (target_cell)
# 因硬墙或泡泡 phase 而被阻挡时，返回该轴上玩家中心**允许到达的最远位置**。
# 不阻挡时返回 sentinel：move>0 取 INT_MAX 近似值，move<0 取 INT_MIN 近似值。
# 调用方据此对 tentative 做一次 mini/maxi 钳制。
#
# 限位定义（统一语义：玩家滑到边界）：
# - 硬墙（is_hard_blocked=true 或越界）：玩家停在该格"近侧"边界；move>0 时为 target.x*M-1（保证 floor_div 归 foot_cell），
#   move<0 时为 (target.x+1)*M（玩家在 target+1 格的最左，floor_div 归 target+1 格）。
# - bubble phase：边界 = bubble_center + sign·阈值（B=M/2, C=M）。
# - 同时存在硬墙 + 泡泡：取较保守（更靠玩家当前位置）那个。
# 注意：current_abs 当前未参与计算，但保留参数以便将来手感调整（如"贴墙后停 1 格距离"等）。
func resolve_axis_blocking_limit_for_player(
	player_id: int,
	target_cell_x: int,
	target_cell_y: int,
	current_abs_x: int,
	current_abs_y: int,
	candidate_abs_x: int,
	candidate_abs_y: int,
	move_x: int,
	move_y: int
) -> int:
	var unbounded := _axis_unbounded_sentinel(move_x, move_y)
	var limit := unbounded

	# 1) 静态碰撞：当前朝向下不允许进入 target_cell。
	var current_cell_x := int(GridMotionMath.abs_to_cell_and_offset_x(current_abs_x).get("cell_x", 0))
	var current_cell_y := int(GridMotionMath.abs_to_cell_and_offset_y(current_abs_y).get("cell_y", 0))
	if is_transition_tile_blocked(current_cell_x, current_cell_y, target_cell_x, target_cell_y):
		var hard_limit := _hard_wall_axis_limit(target_cell_x, target_cell_y, move_x, move_y)
		limit = _tighten_axis_limit(limit, hard_limit, move_x, move_y)

	# 2) 泡泡 phase 阻挡：基于该 bubble 与玩家的当前 phase 边界。
	var bubble_id := get_bubble_at(target_cell_x, target_cell_y)
	if bubble_id != -1:
		var bubble_limit := _bubble_phase_axis_limit(
			player_id,
			bubble_id,
			candidate_abs_x,
			candidate_abs_y,
			move_x,
			move_y
		)
		limit = _tighten_axis_limit(limit, bubble_limit, move_x, move_y)

	return limit


static func _hard_wall_axis_limit(target_cell_x: int, target_cell_y: int, move_x: int, move_y: int) -> int:
	# 物理模型：玩家碰撞框 M×M，中心对齐 abs_pos；墙 cell 碰撞框 M×M，中心对齐 cell_center。
	# 两 M×M 框不重叠条件：|abs_pos - wall_center| >= M。
	# 即玩家中心与墙中心最小距离 = M（半格判定不正确，应是整格）。
	#
	# 等价于：玩家最远停在 foot_cell 中心（move>0 撞 target_cell 时，玩家停在 target_cell-1 的中心）。
	# 与泡泡 phase C 完全同语义（硬墙=永远 phase C，玩家中心距阻挡中心 = M）。
	if move_x > 0:
		# 玩家朝右撞 target_cell：limit = target_center - M = (target_cell - 1) 的中心
		return target_cell_x * GridMotionMath.CELL_UNITS - GridMotionMath.HALF_CELL_UNITS
	if move_x < 0:
		# 玩家朝左撞 target_cell：limit = target_center + M
		return (target_cell_x + 1) * GridMotionMath.CELL_UNITS + GridMotionMath.HALF_CELL_UNITS
	if move_y > 0:
		return target_cell_y * GridMotionMath.CELL_UNITS - GridMotionMath.HALF_CELL_UNITS
	return (target_cell_y + 1) * GridMotionMath.CELL_UNITS + GridMotionMath.HALF_CELL_UNITS


static func _axis_unbounded_sentinel(move_x: int, move_y: int) -> int:
	# 半 int63 量级足够大于任何合法世界坐标；保持 GD/native 行为一致。
	if move_x > 0 or move_y > 0:
		return 1 << 31
	return -(1 << 31)


static func _tighten_axis_limit(current: int, candidate: int, move_x: int, move_y: int) -> int:
	if move_x > 0 or move_y > 0:
		return mini(current, candidate)
	return maxi(current, candidate)


func _bubble_phase_axis_limit(
	player_id: int,
	bubble_id: int,
	candidate_abs_x: int,
	candidate_abs_y: int,
	move_x: int,
	move_y: int
) -> int:
	var bubble := get_bubble(bubble_id)
	if bubble == null or not bubble.alive:
		return _axis_unbounded_sentinel(move_x, move_y)

	var center := resolve_bubble_reference_center(bubble, Vector2i(candidate_abs_x, candidate_abs_y))
	var phase = BubblePassPhaseHelper.find_phase(bubble, player_id)
	if phase == null:
		# 无 phase 条目：在当前模式下视为完全阻挡（C 等价），但要按 move 方向选 sign。
		if MovementTuning.bubble_phase_init_mode() == 0:
			return _phase_axis_distance_limit(
				center.x if move_x != 0 else center.y,
				_default_block_sign(candidate_abs_x if move_x != 0 else candidate_abs_y, center.x if move_x != 0 else center.y),
				BubblePassPhaseScript.Phase.C,
				move_x,
				move_y
			)
		# 懒初始化模式：按候选位置 d 推断的 phase 等价于不阻挡（A,A 区段内）。
		return _axis_unbounded_sentinel(move_x, move_y)

	if move_x != 0:
		return _phase_axis_distance_limit(center.x, int(phase.sign_x), int(phase.phase_x), move_x, move_y)
	return _phase_axis_distance_limit(center.y, int(phase.sign_y), int(phase.phase_y), move_x, move_y)


static func _phase_axis_distance_limit(center_axis: int, sign_axis: int, phase_axis: int, move_x: int, move_y: int) -> int:
	# A 阶段不阻挡；B/C 给出 d·sign >= 阈值 → 边界 = center + sign·阈值
	if phase_axis == BubblePassPhaseScript.Phase.A:
		return _axis_unbounded_sentinel(move_x, move_y)
	if sign_axis == 0:
		# 防御：B/C 必须有 sign，否则按完全阻挡处理（限位收紧到 center）。
		return center_axis
	var threshold := GridMotionMath.HALF_CELL_UNITS if phase_axis == BubblePassPhaseScript.Phase.B else GridMotionMath.CELL_UNITS
	return center_axis + sign_axis * threshold


static func _default_block_sign(player_axis: int, center_axis: int) -> int:
	if player_axis > center_axis:
		return 1
	if player_axis < center_axis:
		return -1
	return 1


# 双轴 phase 状态机的阻挡判定。
# 语义：A=该轴自由；B(s)=候选位置在该轴必须满足 d·s >= M/2；C(s)=d·s >= M。
# 任一轴违反则判定阻挡；两轴都在 A 则完全放行。
# pass_phases 中无该玩家条目时：
#   BUBBLE_PHASE_INIT_MODE == 0 → 视为完全阻挡（未重叠进泡泡）
#   BUBBLE_PHASE_INIT_MODE == 1 → 懒初始化：按候选位置的 d 计算初始 phase 再判
func is_bubble_blocking_at_pos(
	player_id: int,
	bubble_id: int,
	candidate_abs_x: int,
	candidate_abs_y: int
) -> bool:
	var bubble := get_bubble(bubble_id)
	if bubble == null or not bubble.alive:
		return false

	var center := resolve_bubble_reference_center(bubble, Vector2i(candidate_abs_x, candidate_abs_y))
	var d_x := candidate_abs_x - center.x
	var d_y := candidate_abs_y - center.y

	var phase = BubblePassPhaseHelper.find_phase(bubble, player_id)
	if phase == null:
		if MovementTuning.bubble_phase_init_mode() == 0:
			return true
		# 懒初始化：按当前候选位置的 d 决定初始 phase，但不在查询中写回状态（纯读）。
		phase = _compute_lazy_phase(d_x, d_y)

	return _phase_blocks(phase, d_x, d_y)


static func _phase_blocks(phase, d_x: int, d_y: int) -> bool:
	if int(phase.phase_x) == BubblePassPhaseScript.Phase.A and int(phase.phase_y) == BubblePassPhaseScript.Phase.A:
		return false
	if _axis_violates(int(phase.phase_x), int(phase.sign_x), d_x):
		return true
	if _axis_violates(int(phase.phase_y), int(phase.sign_y), d_y):
		return true
	return false


static func _axis_violates(axis_phase: int, axis_sign: int, d: int) -> bool:
	if axis_phase == BubblePassPhaseScript.Phase.A:
		return false
	var signed_d := d * axis_sign
	if axis_phase == BubblePassPhaseScript.Phase.B:
		return signed_d < GridMotionMath.HALF_CELL_UNITS
	return signed_d < GridMotionMath.CELL_UNITS


static func _compute_lazy_phase(d_x: int, d_y: int) -> Variant:
	var phase = BubblePassPhaseScript.new()
	phase.player_id = -1
	phase.phase_x = _lazy_axis_phase(d_x)
	phase.sign_x = 0 if int(phase.phase_x) == BubblePassPhaseScript.Phase.A else _sign_of(d_x)
	phase.phase_y = _lazy_axis_phase(d_y)
	phase.sign_y = 0 if int(phase.phase_y) == BubblePassPhaseScript.Phase.A else _sign_of(d_y)
	return phase


static func _lazy_axis_phase(d: int) -> int:
	var abs_d := absi(d)
	if abs_d < GridMotionMath.HALF_CELL_UNITS:
		return BubblePassPhaseScript.Phase.A
	if abs_d < GridMotionMath.CELL_UNITS:
		return BubblePassPhaseScript.Phase.B
	return BubblePassPhaseScript.Phase.C


static func _sign_of(value: int) -> int:
	if value > 0:
		return 1
	if value < 0:
		return -1
	return 1


static func _pass_bit_from_delta(dx: int, dy: int) -> int:
	if dx == 1 and dy == 0:
		return TileConstants.PASS_E
	if dx == -1 and dy == 0:
		return TileConstants.PASS_W
	if dx == 0 and dy == 1:
		return TileConstants.PASS_S
	if dx == 0 and dy == -1:
		return TileConstants.PASS_N
	return 0


func _is_bubble_blocking_for_player(player_id: int, bubble_id: int) -> bool:
	var bubble := get_bubble(bubble_id)
	if bubble == null or not bubble.alive:
		return false
	# 兼容 API：没有候选位置时用该泡泡参考中心处作为候选，等价于"玩家踩到泡泡中心"。
	var center := resolve_bubble_reference_center(bubble, Vector2i(
		GridMotionMath.get_cell_center_abs_x(bubble.cell_x),
		GridMotionMath.get_cell_center_abs_y(bubble.cell_y)
	))
	return is_bubble_blocking_at_pos(player_id, bubble_id, center.x, center.y)

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
