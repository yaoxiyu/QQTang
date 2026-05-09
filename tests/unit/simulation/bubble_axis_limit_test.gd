extends "res://tests/gut/base/qqt_unit_test.gd"

# 验证泡泡阻挡的轴向限位查询 + 端到端 movement 不抖动。
# 前 4 个子测试是纯 SimQueries 单元测试，不依赖 native kernel。
# 后 2 个端到端测试调 MovementSystem，走 native kernel——前置：tests/scripts/run_native_suite.ps1
# 已先 build native；用 run_gut_suite.ps1 直跑时需手动确保 dll 已构建。

const BubblePassPhaseScript = preload("res://gameplay/simulation/entities/bubble_pass_phase.gd")
const BubblePassPhaseHelper = preload("res://gameplay/simulation/movement/bubble_pass_phase_helper.gd")
const GridMotionMath = preload("res://gameplay/simulation/movement/grid_motion_math.gd")
const NativeKernelRuntimeScript = preload("res://gameplay/native_bridge/native_kernel_runtime.gd")
const M := GridMotionMath.CELL_UNITS  # 1000
const HALF_M := GridMotionMath.HALF_CELL_UNITS  # 500


func test_main() -> void:
	_test_axis_limit_phase_b_stable_at_boundary()
	_test_axis_limit_phase_c_stable_at_boundary()
	_test_axis_limit_hard_wall_blocks_at_cell_edge()
	_test_axis_limit_no_block_returns_unbounded()
	_test_movement_does_not_oscillate_against_phase_b_wall()
	_test_movement_can_approach_hard_wall_from_open_cell()


func _test_axis_limit_phase_b_stable_at_boundary() -> void:
	# 泡泡在 cell (5,5)，玩家 phase_x = B(+)；玩家从右侧朝泡泡走（move_x=-1）。
	# tentative 在 d_x=400 (abs_x=5900)，被判定阻挡；
	# axis_limit 应等于 phase B 边界 = 5500 + 500 = 6000，clamp 后 abs=6000，下一帧不再倒退。
	var world := _build_minimal_world()
	var player_id: int = world.state.players.active_ids[0]
	var bubble_id := world.state.bubbles.spawn_bubble(player_id, 5, 5, 1, 100)
	var bubble := world.state.bubbles.get_bubble(bubble_id)
	var phase = BubblePassPhaseScript.new()
	phase.player_id = player_id
	phase.phase_x = BubblePassPhaseScript.Phase.B
	phase.sign_x = 1
	phase.phase_y = BubblePassPhaseScript.Phase.A
	BubblePassPhaseHelper.upsert_phase(bubble, phase)
	world.state.bubbles.update_bubble(bubble)
	# 注册到 bubbles_by_cell（spawn_bubble 不写索引，正常路径在 bubble_placement_system 里写）
	_register_bubble_index(world, bubble_id, 5, 5)

	# tentative=5900：在 phase B(+) 下违反约束。
	# 玩家当前位置不重要（不是硬墙场景），传 6500 即可。
	var limit := world.queries.resolve_axis_blocking_limit_for_player(
		player_id, 5, 5, 6500, GridMotionMath.get_cell_center_abs_y(5), 5900, GridMotionMath.get_cell_center_abs_y(5), -1, 0
	)
	_assert(limit == 6000, "phase B(+) limit should be center+M/2=6000, got %d" % limit)

	# 玩家当前在 abs_x=6500（cell 6 中心），向左 step_units=100 → tentative=6400。
	# move<0 时 clamped = max(6400, 6000) = 6400，未阻挡。
	limit = world.queries.resolve_axis_blocking_limit_for_player(
		player_id, 5, 5, 6500, GridMotionMath.get_cell_center_abs_y(5), 6400, GridMotionMath.get_cell_center_abs_y(5), -1, 0
	)
	_assert(limit == 6000, "limit constant for same target/move regardless of tentative")

	world.dispose()


func _test_axis_limit_phase_c_stable_at_boundary() -> void:
	var world := _build_minimal_world()
	var player_id: int = world.state.players.active_ids[0]
	var bubble_id := world.state.bubbles.spawn_bubble(player_id, 5, 5, 1, 100)
	var bubble := world.state.bubbles.get_bubble(bubble_id)
	var phase = BubblePassPhaseScript.new()
	phase.player_id = player_id
	phase.phase_x = BubblePassPhaseScript.Phase.C
	phase.sign_x = 1
	phase.phase_y = BubblePassPhaseScript.Phase.A
	BubblePassPhaseHelper.upsert_phase(bubble, phase)
	world.state.bubbles.update_bubble(bubble)
	_register_bubble_index(world, bubble_id, 5, 5)

	# C(+) 边界 = center + M = 5500 + 1000 = 6500（即 cell 6 左边界 = cell 5 右边界）
	var limit := world.queries.resolve_axis_blocking_limit_for_player(
		player_id, 5, 5, 6700, GridMotionMath.get_cell_center_abs_y(5), 6400, GridMotionMath.get_cell_center_abs_y(5), -1, 0
	)
	_assert(limit == 6500, "phase C(+) limit should be center+M=6500, got %d" % limit)
	world.dispose()


func _test_axis_limit_hard_wall_blocks_at_cell_edge() -> void:
	# 物理模型：玩家碰撞框 M×M，墙 cell 碰撞框 M×M，
	# 两 M×M 框不重叠 ⟺ |abs_pos - wall_center| >= M（角色中心与墙中心最小距离 = M）。
	# BuiltinMapFactory 第一行第一列是 '#'（cell(0,1) 是墙）。
	var world := _build_minimal_world()
	var player_id: int = world.state.players.active_ids[0]
	# (0,1) 是墙，玩家在 abs_x=1100 朝它走（move_x=-1）。
	# limit = (target+1)*M + M/2 = 1*1000 + 500 = 1500（cell 1 中心，距墙中心 500=M/2 不对——应是 M）。
	# 等等：墙 cell=0 中心=500，玩家中心最小距 M=1000 → 玩家最远到 abs=1500（cell 1 中心）。
	var limit := world.queries.resolve_axis_blocking_limit_for_player(
		player_id, 0, 1, 1100, GridMotionMath.get_cell_center_abs_y(1), 1000, GridMotionMath.get_cell_center_abs_y(1), -1, 0
	)
	_assert(limit == 1500, "hard wall limit should keep player center M away from wall center, got %d (expected 1500)" % limit)
	world.dispose()


func _test_axis_limit_no_block_returns_unbounded() -> void:
	# 空格子 + 无泡泡：limit 应是 sentinel（极大/极小值），不收紧。
	var world := _build_minimal_world()
	var player_id: int = world.state.players.active_ids[0]
	# (5,5) 在 BuiltinMapFactory 里是 'M' 中央格，可通行无泡泡。
	var limit := world.queries.resolve_axis_blocking_limit_for_player(
		player_id, 5, 5, 5500, 5500, 5500, 5500, 1, 0
	)
	_assert(limit > 1_000_000, "no-block limit should be a large sentinel for move_x>0, got %d" % limit)

	limit = world.queries.resolve_axis_blocking_limit_for_player(
		player_id, 5, 5, 5500, 5500, 5500, 5500, -1, 0
	)
	_assert(limit < -1_000_000, "no-block limit should be small sentinel for move_x<0, got %d" % limit)
	world.dispose()


func _test_movement_does_not_oscillate_against_phase_b_wall() -> void:
	# 端到端：玩家放在 cell(6,5) 中心，泡泡在 (5,5)，phase_x=B(+)。
	# 持续输入 move=(-1,0) 跑 5 个 tick。每 tick 后玩家 abs_x 应单调非增直到 6000，
	# 之后稳定不再增减。旧 bug 下 abs_x 会在 6000 ↔ 6500 之间反复。
	var native_available := _is_native_movement_available()

	var world := _build_minimal_world()
	var player_id: int = world.state.players.active_ids[0]

	# 初始化玩家位置
	var player := world.state.players.get_player(player_id)
	GridMotionMath.write_player_abs_pos(player, GridMotionMath.get_cell_center_abs_x(6), GridMotionMath.get_cell_center_abs_y(5))
	player.speed_level = 1
	player.last_applied_command.move_x = -1
	player.last_applied_command.move_y = 0
	world.state.players.update_player(player)

	# 放泡泡，登记 phase
	var bubble_id := world.state.bubbles.spawn_bubble(player_id, 5, 5, 1, 100)
	var bubble := world.state.bubbles.get_bubble(bubble_id)
	var phase = BubblePassPhaseScript.new()
	phase.player_id = player_id
	phase.phase_x = BubblePassPhaseScript.Phase.B
	phase.sign_x = 1
	phase.phase_y = BubblePassPhaseScript.Phase.A
	BubblePassPhaseHelper.upsert_phase(bubble, phase)
	world.state.bubbles.update_bubble(bubble)
	_register_bubble_index(world, bubble_id, 5, 5)

	# 跑 1 tick：MovementSystem 应钳住 abs_x 在 6000，不越过、不抖回 6500。
	var movement := MovementSystem.new()
	var ctx := SimContext.new()
	ctx.state = world.state
	ctx.queries = world.queries
	ctx.tick = 1
	ctx.events = world.events
	movement.execute(ctx)
	var p1 := world.state.players.get_player(player_id)
	var x1 := GridMotionMath.to_abs_x(p1.cell_x, p1.offset_x)
	if not native_available:
		# native 不可用：MovementSystem.execute 会跳过该帧，玩家应不动。
		_assert(x1 == 6500, "native unavailable: player must remain at start abs_x=6500, got %d" % x1)
		world.dispose()
		return
	_assert(x1 >= 6000 and x1 <= 6500, "tick1 abs_x must stay in [6000,6500], got %d" % x1)

	# 多跑几 tick，确保不抖回 6500。
	for i in range(5):
		ctx.tick += 1
		movement.execute(ctx)
		var p := world.state.players.get_player(player_id)
		var x := GridMotionMath.to_abs_x(p.cell_x, p.offset_x)
		_assert(x >= 6000, "tick%d abs_x must not violate phase B boundary, got %d" % [ctx.tick, x])
		# 关键反抖：玩家不应被反向推回比上一帧更远。
		_assert(x <= x1, "tick%d abs_x must be monotone non-increasing (no reverse clamp), got %d vs prev %d" % [ctx.tick, x, x1])
		x1 = x

	world.dispose()


func _test_movement_can_approach_hard_wall_from_open_cell() -> void:
	# 物理模型：玩家碰撞 M×M，墙 M×M → 玩家中心距墙中心最小 M。
	# 玩家从 cell(1,1) 中心 abs_x=1500 朝 cell(0,1) 墙走，墙中心=500，limit=1500。
	# 玩家初始就在 limit 上 → 第一个 tick 立刻 BLOCKED，位置不变。
	# 撞墙后 move_state=BLOCKED（表现层据此播放朝墙的移动动画）。
	var native_available := _is_native_movement_available()

	var world := _build_minimal_world()
	var player_id: int = world.state.players.active_ids[0]
	var player := world.state.players.get_player(player_id)
	GridMotionMath.write_player_abs_pos(
		player,
		GridMotionMath.get_cell_center_abs_x(1),
		GridMotionMath.get_cell_center_abs_y(1)
	)
	player.speed_level = 1
	player.last_applied_command.move_x = -1
	player.last_applied_command.move_y = 0
	world.state.players.update_player(player)

	var movement := MovementSystem.new()
	var ctx := SimContext.new()
	ctx.state = world.state
	ctx.queries = world.queries
	ctx.tick = 1
	ctx.events = world.events

	movement.execute(ctx)
	var p1 := world.state.players.get_player(player_id)
	var x1 := GridMotionMath.to_abs_x(p1.cell_x, p1.offset_x)
	if not native_available:
		_assert(x1 == 1500, "native unavailable: player must remain at start abs_x=1500, got %d" % x1)
		world.dispose()
		return
	# 玩家初始 abs=1500 已在 limit=1500 上 → 不能朝墙位移。
	_assert(x1 == 1500, "玩家在 cell 中心已贴墙，应保持 abs_x=1500，实际 %d" % x1)
	_assert(p1.move_state == PlayerState.MoveState.BLOCKED, "撞墙后 move_state 应为 BLOCKED，实际 %d" % p1.move_state)

	# 持续走若干 tick，位置始终不变，状态保持 BLOCKED。
	for i in range(20):
		ctx.tick += 1
		movement.execute(ctx)
	var pf := world.state.players.get_player(player_id)
	var xf := GridMotionMath.to_abs_x(pf.cell_x, pf.offset_x)
	_assert(xf == 1500, "玩家持续撞墙后 abs_x 仍应为 1500，实际 %d" % xf)
	_assert(pf.move_state == PlayerState.MoveState.BLOCKED, "持续撞墙时 move_state 应保持 BLOCKED")

	world.dispose()


func _is_native_movement_available() -> bool:
	return NativeKernelRuntimeScript.is_available() and NativeKernelRuntimeScript.has_movement_kernel()


func _build_minimal_world() -> SimWorld:
	var world := SimWorld.new()
	world.rng = SimRng.new(42)
	world.bootstrap(SimConfig.new(), {"grid": BuiltinMapFactory.build_basic_map()})
	return world


func _register_bubble_index(world: SimWorld, bubble_id: int, cell_x: int, cell_y: int) -> void:
	var idx := world.state.grid.to_cell_index(cell_x, cell_y)
	if idx >= 0 and idx < world.state.indexes.bubbles_by_cell.size():
		world.state.indexes.bubbles_by_cell[idx] = bubble_id
	if not world.state.indexes.active_bubble_ids.has(bubble_id):
		world.state.indexes.active_bubble_ids.append(bubble_id)


func _assert(condition: bool, message: String) -> void:
	assert_true(condition, message)
