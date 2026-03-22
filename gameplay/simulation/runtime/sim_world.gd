# 角色：
# 模拟世界，仿真唯一入口
#
# 读写边界：
# - 由 SimulationRunner 调用
# - 持有整个仿真上下文
#
# 禁止事项：
# - 不得在此文件中写规则逻辑

class_name SimWorld
extends RefCounted

# ====================
# 核心组件
# ====================

var config: SimConfig = SimConfig.new()
var state: SimState = SimState.new()
var queries: SimQueries = SimQueries.new()
var events: SimEventBuffer = SimEventBuffer.new()
var rng: SimRng = SimRng.new(12345)
var input_buffer: InputBuffer = InputBuffer.new()
var pipeline: SystemPipeline = SystemPipeline.new()

# ====================
# 初始化
# ====================

func _init() -> void:
	queries.set_state(state)
	pipeline.initialize_default_pipeline()

# ====================
# 核心方法
# ====================

# 启动对局
func bootstrap(p_config: SimConfig, bootstrap_data: Dictionary) -> void:
	config = p_config
	state.initialize_default()
	input_buffer.clear()

	if "grid" in bootstrap_data:
		state.grid = bootstrap_data["grid"]

	# 重新初始化 indexes，因为 grid 可能已替换
	state.indexes.initialize(state.grid.width * state.grid.height)

	# 设置默认模式
	state.mode.mode_runtime_type = "default"

	# 初始化出生点玩家
	_initialize_spawned_players()

# 初始化出生点的玩家
func _initialize_spawned_players() -> void:
	var grid = state.grid
	var player_count = 2  # Phase0 默认2人对局

	# 遍历地图，寻找所有出生点
	var spawn_points: Array[Vector2i] = []

	for y in range(grid.height):
		for x in range(grid.width):
			var cell = grid.get_static_cell(x, y)
			if (cell.tile_flags & TileConstants.TILE_IS_SPAWN) != 0:
				spawn_points.append(Vector2i(x, y))

	# 如果没有出生点，使用角落作为默认出生点
	if spawn_points.size() == 0:
		spawn_points.append(Vector2i(1, 1))
		spawn_points.append(Vector2i(grid.width - 2, grid.height - 2))

	# 创建玩家（轮流分配出生点）
	for i in range(player_count):
		var spawn_point = spawn_points[i % spawn_points.size()]
		var player_id = state.players.add_player(
			i,                    # player_slot
			i % 2,                # team_id (0 或 1)
			spawn_point.x,        # cell_x
			spawn_point.y         # cell_y
		)

		# 确保出生时 bomb_available 正确
		var player = state.players.get_player(player_id)
		if player != null:
			player.alive = true
			player.life_state = PlayerState.LifeState.NORMAL
			player.bomb_available = player.bomb_capacity
	

# 推进一个 Tick
func step() -> Dictionary:
	# 更新 tick
	state.match_state.tick += 1

	# 构建当前 Tick 的输入帧
	var player_slots: Array[int] = []
	for pid in state.players.active_ids:
		var p = state.players.get_player(pid)
		if p != null:
			player_slots.append(p.player_slot)

	var commands = input_buffer.consume_or_build_for_tick(state.match_state.tick, player_slots)

	# 构建上下文
	var ctx = SimContext.new()
	ctx.config = config
	ctx.state = state
	ctx.queries = queries
	ctx.events = events
	ctx.rng = rng
	ctx.tick = state.match_state.tick
	ctx.commands = commands
	ctx.scratch = SimScratch.new()
	ctx.worksets = SimWorksets.new()

	# 执行所有系统（PreTickSystem 会在第一位执行）
	pipeline.execute_all(ctx)

	# 返回结果
	return {
		tick = state.match_state.tick,
		events = events.get_events(),
		phase = state.match_state.phase
	}

# 加入输入
func enqueue_input(input_frame: InputFrame) -> void:
	input_buffer.push_input_frame(input_frame)
