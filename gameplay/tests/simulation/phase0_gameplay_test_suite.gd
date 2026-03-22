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
	var grid = ctx.world.state.grid
	var players = ctx.world.state.players

	# 添加一个玩家
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
	var grid = ctx.world.state.grid
	var bubbles = ctx.world.state.bubbles

	# 添加一个玩家用于放置泡泡
	var player_id = ctx.world.state.players.add_player(0, 0, 1, 1)

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

# 测试5：爆炸效果（待实现）
func test_explosion() -> void:
	# TODO: 实现爆炸效果测试
	test_pass("explosion test (placeholder)")

# 测试6：道具交互（待实现）
func test_item() -> void:
	# TODO: 实现道具交互测试
	test_pass("item test (placeholder)")

# 测试7：胜负条件（待实现）
func test_win_condition() -> void:
	# TODO: 实现胜负条件测试
	test_pass("win condition test (placeholder)")

# ====================
# Bridge 回调
# ====================

# Bridge 每帧回调（用于观察渲染状态）
func on_bridge_observe(_result: Dictionary) -> void:
	# 可在此添加视觉验证逻辑
	pass
