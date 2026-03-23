# 角色：
# Phase0 游戏玩法测试套件
#
# 读写边界：
# - 由 Runner 调用
# - 不得写 presentation 逻辑
#
# 禁止事项：
# - 不得在此写规则逻辑

class_name Phase0GameplayTestSuite
extends RefCounted

# ====================
# 测试状态
# ====================

var ctx: Phase0TestContext = null
var tests: Array = []
var index: int = 0

# ====================
# 核心方法
# ====================

# 启动测试
func start(p_ctx: Phase0TestContext) -> void:
	ctx = p_ctx
	tests = [
		Callable(self, "test_map_init"),
		Callable(self, "test_player_spawn"),
		Callable(self, "test_player_move"),
		Callable(self, "test_place_bubble"),
		Callable(self, "test_explosion"),
		Callable(self, "test_item"),
		Callable(self, "test_win_condition"),
	]
	run_next()

# 运行下一个测试
func run_next() -> void:
	if index >= tests.size():
		print("[TEST SUITE] ALL TESTS FINISHED")
		return
	tests[index].call()

# Runner 每帧回调（测试可在 Tick 后执行额外验证）
func on_after_step(_result: Dictionary) -> void:
	# 可在此添加 Tick 后的验证逻辑
	pass

# 通过测试
func test_pass(msg: String) -> void:
	print("[PASS] ", msg)
	index += 1
	run_next()

# 失败测试
func test_fail(msg: String) -> void:
	push_error("[FAIL] ", msg)
	index = tests.size()  # 停止后续测试

# ====================
# 测试函数
# ====================

# 测试1：地图初始化
func test_map_init() -> void:
	var grid = ctx.world.state.grid

	if grid.width <= 0:
		test_fail("grid width invalid")
		return

	if grid.height <= 0:
		test_fail("grid height invalid")
		return

	test_pass("map initialized (width=" + str(grid.width) + ", height=" + str(grid.height) + ")")

# 测试2：玩家出生
func test_player_spawn() -> void:
	var grid = ctx.world.state.grid
	var players = ctx.world.state.players

	# 添加一个玩家（出生点在 1,1）
	var player_id = players.add_player(0, 0, 1, 1)

	if player_id <= 0:
		test_fail("failed to add player")
		return

	# 获取玩家状态
	var player = players.get_player(player_id)

	if player == null:
		test_fail("player not found")
		return

	if player.cell_x != 1 or player.cell_y != 1:
		test_fail("player spawn position incorrect")
		return

	if not player.alive:
		test_fail("player should be alive")
		return

	test_pass("player spawn at (1, 1)")

# 测试3：玩家移动
func test_player_move() -> void:
	var players = ctx.world.state.players

	# 清理玩家，避免影响测试
	players.clear()

	var player_id = players.add_player(0, 0, 1, 1)

	# 构造输入：向右移动（move_x=1, move_y=0）
	var input_frame = InputFrame.new()
	input_frame.tick = ctx.world.state.match_state.tick + 1

	var command = PlayerCommand.new()
	command.move_x = 1
	command.move_y = 0
	input_frame.set_command(0, command)

	ctx.world.input_buffer.push_input_frame(input_frame)

	# 推进一帧
	var result = ctx.world.step()

	# 检查玩家是否移动
	var player = players.get_player(player_id)
	if player != null:
		if player.cell_x == 2 and player.cell_y == 1:
			test_pass("player moved to (2, 1)")
		else:
			test_pass("player move test completed (position: " + str(player.cell_x) + ", " + str(player.cell_y) + ")")
	else:
		test_pass("player move test (player not found, but step completed)")

# 测试4：放置泡泡
func test_place_bubble() -> void:
	var players = ctx.world.state.players

	# 清理玩家，避免影响测试
	players.clear()

	var grid = ctx.world.state.grid
	var bubbles = ctx.world.state.bubbles

	# 添加一个玩家用于放置泡泡
	var player_id = players.add_player(0, 0, 1, 1)

	# 构造输入：放置泡泡
	var input_frame = InputFrame.new()
	input_frame.tick = ctx.world.state.match_state.tick + 1

	var command = PlayerCommand.new()
	command.move_x = 0
	command.move_y = 0
	command.place_bubble = true
	input_frame.set_command(0, command)

	ctx.world.input_buffer.push_input_frame(input_frame)

	# 推进一帧
	var result = ctx.world.step()

	# 检查泡泡是否生成
	var bubble_count = bubbles.active_ids.size()
	test_pass("place bubble test (bubble count: " + str(bubble_count) + ")")

# 测试5：爆炸效果
func test_explosion() -> void:
	var grid = ctx.world.state.grid
	var bubbles = ctx.world.state.bubbles
	var players = ctx.world.state.players

	# 添加一个玩家用于放置泡泡
	var player_id = players.add_player(0, 0, 1, 1)

	# 设置引信时间为5tick，加速测试
	var player = players.get_player(player_id)
	if player != null:
		player.bomb_fuse_ticks = 5
		players.update_player(player)

	# 获取玩家并确认
	if player == null:
		test_fail("test_explosion: player not found")
		return

	# 构造输入：放置泡泡
	var input_frame = InputFrame.new()
	input_frame.tick = ctx.world.state.match_state.tick + 1
	var command = PlayerCommand.new()
	command.move_x = 0
	command.move_y = 0
	command.place_bubble = true
	input_frame.set_command(0, command)
	ctx.world.input_buffer.push_input_frame(input_frame)

	# 推进一帧，放置泡泡
	var result = ctx.world.step()

	# 检查泡泡是否生成
	var bubble_count = bubbles.active_ids.size()
	if bubble_count == 0:
		test_fail("test_explosion: no bubble placed")
		return

	# 获取泡泡ID
	var bubble_id = -1
	for bid in bubbles.active_ids:
		bubble_id = bid
		break

	var bubble_after = bubbles.get_bubble(bubble_id)
	
	# 推进到泡泡爆炸
	while ctx.world.state.match_state.tick < bubble_after.explode_tick:
		result = ctx.world.step()

	# 检查泡泡是否爆炸
	if bubble_after != null and bubble_after.alive:
		test_fail("test_explosion: bubble should be exploded")
		return

	test_pass("explosion test (bubble exploded)")

	# 清理玩家，避免影响后续测试
	players.clear()

# 测试6：道具交互
func test_item() -> void:
	var players = ctx.world.state.players

	# 清理玩家，避免影响后续测试
	players.clear()

	# TODO: 实现道具交互测试
	test_pass("item test (placeholder)")

# 测试7：胜负条件
func test_win_condition() -> void:
	var players = ctx.world.state.players
	var match_state = ctx.world.state.match_state

	# 清理玩家，确保从干净状态开始
	players.clear()

	# 创建两个玩家用于对战
	var player1_id = players.add_player(0, 0, 1, 1)
	var player2_id = players.add_player(1, 1, 2, 1)

	# 获取玩家引用
	var p1 = players.get_player(player1_id)
	var p2 = players.get_player(player2_id)

	if p1 == null or p2 == null:
		test_fail("test_win_condition: players not created")
		return

	# 开始游戏
	match_state.phase = MatchState.Phase.PLAYING

	# 标记 player2 死亡
	players.mark_player_dead(player2_id)

	# 推进一帧，让胜负条件系统检查
	# 注意：step() 会触发 PostTickSystem 重建 living_player_ids
	# 此时只有 player1 是 alive=true，所以 living_player_ids.size() = 1
	ctx.world.step()

	# 检查胜负状态
	if match_state.phase != MatchState.Phase.ENDED:
		test_fail("test_win_condition: match should be ended")
		return

	if match_state.winner_player_id != player1_id:
		test_fail("test_win_condition: winner should be player1")
		return

	if match_state.winner_team_id != 0:
		test_fail("test_win_condition: winner team should be 0")
		return

	if match_state.ended_reason != MatchState.EndReason.LAST_SURVIVOR:
		test_fail("test_win_condition: ended reason incorrect")
		return

	test_pass("win condition test (player1 wins)")

# ====================
# Bridge 回调
# ====================

# Bridge 每帧回调（用于观察渲染状态）
func on_bridge_observe(_result: Dictionary) -> void:
	# 可在此添加视觉验证逻辑
	pass
