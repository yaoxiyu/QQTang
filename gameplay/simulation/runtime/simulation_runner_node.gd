# 角色：
# Simulation Runner - 测试模式
# 驱动游戏仿真并执行测试套件
#
# 职责：
# 1. 创建 world
# 2. 创建 test context
# 3. 创建 test suite
# 4. 启动测试
# 5. 每 tick 调用 suite
#
# 禁止：
# 不要在 runner 写测试逻辑

extends Node

var world: SimWorld = null
var bridge: Node = null
var test_suite: Phase0GameplayTestSuite = null
var test_ctx: Phase0TestContext = null

func _ready() -> void:
	world = SimWorld.new()

	var config := SimConfig.new()
	var grid := TestMapFactory.build_basic_map()

	world.bootstrap(config, {
		"grid": grid
	})

	# 从同一个场景根节点下找到 PresentationRoot
	bridge = get_parent().get_node("PresentationRoot")

	# 创建测试上下文
	test_ctx = Phase0TestContext.new()
	test_ctx.world = world
	test_ctx.runner = self
	test_ctx.bridge = bridge

	# 创建测试套件
	test_suite = Phase0GameplayTestSuite.new()
	test_suite.start(test_ctx)

func _process(delta: float) -> void:
	# 推进一帧
	var result = world.step()

	# 通知测试套件
	if test_suite != null:
		test_suite.on_after_step(result)

	# 通知桥接器
	if bridge != null:
		bridge.consume_tick(result)
