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

const LogSimulationScript = preload("res://app/logging/log_simulation.gd")

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

# 运行期骨架组件（按当前仿真装配方式挂接）
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
	_init_runtime_scaffold()

func _init_runtime_scaffold() -> void:
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
	_initialize_spawned_players(bootstrap_data)
	state.match_state.phase = MatchState.Phase.PLAYING
	state.indexes.rebuild_from_state(state)
	tick_runner.set_tick(state.match_state.tick)


func _initialize_spawned_players(bootstrap_data: Dictionary = {}) -> void:
	var grid = state.grid
	var spawn_points: Array[Vector2i] = []
	var player_slots := _coerce_dict_array(bootstrap_data.get("player_slots", []))
	var spawn_assignments := _coerce_dict_array(bootstrap_data.get("spawn_assignments", []))
	var character_loadouts := _coerce_dict_array(bootstrap_data.get("character_loadouts", config.system_flags.get("character_loadouts", [])))

	for y in range(grid.height):
		for x in range(grid.width):
			var cell = grid.get_static_cell(x, y)
			if (cell.tile_flags & TileConstants.TILE_IS_SPAWN) != 0:
				spawn_points.append(Vector2i(x, y))

	if spawn_points.size() == 0:
		spawn_points.append(Vector2i(1, 1))
		spawn_points.append(Vector2i(grid.width - 2, grid.height - 2))

	if player_slots.is_empty() and not spawn_assignments.is_empty():
		for assignment in spawn_assignments:
			player_slots.append({
				"peer_id": int(assignment.get("peer_id", -1)),
				"slot_index": int(assignment.get("slot_index", player_slots.size())),
				"team_id": int(assignment.get("team_id", int(assignment.get("slot_index", player_slots.size())) + 1)),
			})

	if player_slots.is_empty():
		for i in range(2):
			player_slots.append({
				"peer_id": i + 1,
				"slot_index": i,
				"team_id": i + 1,
			})

	player_slots.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var slot_a := int(a.get("slot_index", -1))
		var slot_b := int(b.get("slot_index", -1))
		if slot_a == slot_b:
			return int(a.get("peer_id", -1)) < int(b.get("peer_id", -1))
		return slot_a < slot_b
	)

	for i in range(player_slots.size()):
		var player_entry: Dictionary = player_slots[i]
		var slot_index := int(player_entry.get("slot_index", i))
		var team_id := int(player_entry.get("team_id", slot_index + 1))
		var spawn_point := _resolve_spawn_point(slot_index, i, spawn_assignments, spawn_points)
		var player_id = state.players.add_player(slot_index, team_id, spawn_point.x, spawn_point.y)
		var player = state.players.get_player(player_id)
		if player != null:
			player.alive = true
			player.life_state = PlayerState.LifeState.NORMAL
			_apply_character_stats_to_player(player, player_entry, character_loadouts)
			player.bomb_available = player.bomb_capacity


func _resolve_spawn_point(slot_index: int, fallback_index: int, spawn_assignments: Array[Dictionary], spawn_points: Array[Vector2i]) -> Vector2i:
	for assignment in spawn_assignments:
		if int(assignment.get("slot_index", -1)) != slot_index:
			continue
		return Vector2i(
			int(assignment.get("spawn_cell_x", 1)),
			int(assignment.get("spawn_cell_y", 1))
		)
	return spawn_points[fallback_index % spawn_points.size()]


func _apply_character_stats_to_player(player: PlayerState, player_entry: Dictionary, character_loadouts: Array[Dictionary]) -> void:
	var loadout := _find_character_loadout(player_entry, character_loadouts)
	if loadout.is_empty():
		return
	player.bomb_capacity = maxi(1, int(loadout.get("initial_bubble_count", loadout.get("base_bomb_count", player.bomb_capacity))))
	player.max_bomb_capacity = maxi(player.bomb_capacity, int(loadout.get("max_bubble_count", player.max_bomb_capacity)))
	player.bomb_range = maxi(1, int(loadout.get("initial_bubble_power", loadout.get("base_firepower", player.bomb_range))))
	player.max_bomb_range = maxi(player.bomb_range, int(loadout.get("max_bubble_power", player.max_bomb_range)))
	player.speed_level = maxi(1, int(loadout.get("initial_move_speed", loadout.get("base_move_speed", player.speed_level))))
	player.max_speed_level = maxi(player.speed_level, int(loadout.get("max_move_speed", player.max_speed_level)))
	LogSimulationScript.debug(
		"player=%d slot=%d bubbles=%d/%d power=%d/%d speed=%d/%d character=%s" % [
			player.entity_id,
			player.player_slot,
			player.bomb_capacity,
			player.max_bomb_capacity,
			player.bomb_range,
			player.max_bomb_range,
			player.speed_level,
			player.max_speed_level,
			String(loadout.get("character_id", "")),
		],
		"",
		0,
		"simulation.content.character_stats"
	)


func _find_character_loadout(player_entry: Dictionary, character_loadouts: Array[Dictionary]) -> Dictionary:
	var peer_id := int(player_entry.get("peer_id", -1))
	if peer_id >= 0:
		for loadout in character_loadouts:
			if int(loadout.get("peer_id", -2)) == peer_id:
				return loadout
	var slot_index := int(player_entry.get("slot_index", -1))
	for loadout in character_loadouts:
		if int(loadout.get("slot_index", -2)) == slot_index:
			return loadout
	return {}


func _coerce_dict_array(raw_value: Variant) -> Array[Dictionary]:
	var coerced: Array[Dictionary] = []
	if raw_value is Array:
		for entry in raw_value:
			if entry is Dictionary:
				coerced.append(entry)
	return coerced


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
func dispose() -> void:
	if tick_runner != null and is_instance_valid(tick_runner):
		tick_runner.free()
	tick_runner = null
	_pending_commands = null
	input_buffer.clear()
	if events != null:
		events.clear()
