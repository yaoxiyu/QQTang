# LEGACY / PROTOTYPE FILE
# Retained for historical testing or LegacyMigration compatibility.
# Not part of the production battle startup path.

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

var test_suite: GameplayTestSuite = null

func set_test_suite(s: GameplayTestSuite) -> void:
	test_suite = s

func consume_tick(result: Dictionary) -> void:
	# 调用测试套件观察
	if test_suite != null:
		test_suite.on_bridge_observe(result)
