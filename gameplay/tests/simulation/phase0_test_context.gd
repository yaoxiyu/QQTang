# 角色：
# Phase0 测试上下文，传递测试所需资源
#
# 读写边界：
# - 由 Runner 创建并填充
# - 测试函数读取
#
# 禁止事项：
# - 不得在此写测试逻辑

class_name Phase0TestContext
extends RefCounted

# 核心引用
var world: SimWorld = null
var runner: Node = null
var bridge: Node = null

# 当前 Tick
var tick: int = 0
