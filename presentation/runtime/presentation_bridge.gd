# 角色：
# Presentation Bridge - 连接仿真与渲染
#
# 职责：
# 1. 接收 TickResult
# 2. 调用 test suite observe
# 3. 不写测试逻辑
#
# 禁止：
# 不得在此写测试逻辑

extends Node2D

var test_suite: Phase0GameplayTestSuite = null

func set_test_suite(s: Phase0GameplayTestSuite) -> void:
	test_suite = s

func consume_tick(result: Dictionary) -> void:
	# 调用测试套件观察
	if test_suite != null:
		test_suite.on_bridge_observe(result)
