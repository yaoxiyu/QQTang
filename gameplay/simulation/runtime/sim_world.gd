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
var _ctx: SimContext = SimContext.new()
var _input_history_keep_ticks: int = 5

# Phase2 骨架组件（按 04/05 文档挂接）
var tick_runner: TickRunner = TickRunner.new()
var entity_store: EntityStore = EntityStore.new()
var player_system = null
var bubble_system = null
var explosion_system = null
var item_system = null
var combat_system = null
var mode_system = null
var _pending_commands: InputFrame = null

# ====================
# 初始化
# ====================

func _init() -> void:
	queries.set_state(state)
	pipeline.initialize_default_pipeline()
	_init_phase2_scaffold()


func _init_phase2_scaffold() -> void:
	tick_runner.reset()
	_register_ticks()


func _register_ticks() -> void:
	tick_runner.register_phase(TickRunner.TickPhase.INPUT, _tick_input_phase)
	tick_runner.register_phase(TickRunner.TickPhase.MOVE, _tick_simulation_pipeline_phase)


func _tick_input_phase(tick: int) -> void:
	state.match_state.tick = tick

	var player_slots: Array[int] = []
	for pid in state.players.active_ids:
		var p = state.players.get_player(pid)
		if p != null:
			player_slots.append(p.player_slot)

	_pending_commands = input_buffer.consume_or_build_for_tick(tick, player_slots)


func _tick_simulation_pipeline_phase(_tick: int) -> void:
	_ctx.config = config
	_ctx.state = state
	_ctx.queries = queries
	_ctx.events = events
	_ctx.rng = rng
	_ctx.tick = state.match_state.tick
	_ctx.commands = _pending_commands
	pipeline.execute_all(_ctx)

# ====================
# 核心方法
# ====================

func bootstrap(p_config: SimConfig, bootstrap_data: Dictionary) -> void:
	config = p_config
	state.initialize_default()
	input_buffer.clear()

	if "grid" in bootstrap_data:
		state.grid = bootstrap_data["grid"]

	state.indexes.initialize(state.grid.width * state.grid.height)
	state.mode.mode_runtime_type = "default"
	_initialize_spawned_players()
	state.match_state.phase = MatchState.Phase.PLAYING
	state.indexes.rebuild_from_state(state)
	tick_runner.set_tick(state.match_state.tick)


func _initialize_spawned_players() -> void:
	var grid = state.grid
	var player_count = 2
	var spawn_points: Array[Vector2i] = []

	for y in range(grid.height):
		for x in range(grid.width):
			var cell = grid.get_static_cell(x, y)
			if (cell.tile_flags & TileConstants.TILE_IS_SPAWN) != 0:
				spawn_points.append(Vector2i(x, y))

	if spawn_points.size() == 0:
		spawn_points.append(Vector2i(1, 1))
		spawn_points.append(Vector2i(grid.width - 2, grid.height - 2))

	for i in range(player_count):
		var spawn_point = spawn_points[i % spawn_points.size()]
		var player_id = state.players.add_player(i, i % 2, spawn_point.x, spawn_point.y)
		var player = state.players.get_player(player_id)
		if player != null:
			player.alive = true
			player.life_state = PlayerState.LifeState.NORMAL
			player.bomb_available = player.bomb_capacity


func step() -> Dictionary:
	tick_runner.step_one_tick()
	input_buffer.clear_before_tick(state.match_state.tick - _input_history_keep_ticks)
	return {
		tick = state.match_state.tick,
		events = events.get_events(),
		phase = state.match_state.phase
	}


func enqueue_input(input_frame: InputFrame) -> void:
	input_buffer.push_input_frame(input_frame)


func reset_runtime_only() -> void:
	events = SimEventBuffer.new()
	input_buffer.clear()
	_pending_commands = null


func rebuild_runtime_indexes() -> void:
	state.indexes.rebuild_from_state(state)
