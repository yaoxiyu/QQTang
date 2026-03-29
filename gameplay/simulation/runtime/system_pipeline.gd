# 角色：
# 系统管线，管理系统执行顺序
#
# 读写边界：
# - 只管理系统列表和执行顺序
# - 不写具体业务逻辑
#
# 禁止事项：
# - 不得在这里写系统逻辑

class_name SystemPipeline
extends RefCounted

const TimeLimitSystemScript = preload("res://gameplay/simulation/systems/time_limit_system.gd")

# 系统列表
var _systems: Array[ISimSystem] = []

# ====================
# 核心方法
# ====================

# 初始化默认系统管线
func initialize_default_pipeline() -> void:
	_systems.clear()

	# 按固定顺序添加系统
	add_system(PreTickSystem.new())
	add_system(InputSystem.new())
	add_system(MovementSystem.new())
	add_system(BubblePlacementSystem.new())
	add_system(BombFuseSystem.new())
	add_system(ExplosionResolveSystem.new())
	add_system(StatusEffectSystem.new())
	add_system(ItemSpawnSystem.new())
	add_system(ItemPickupSystem.new())
	add_system(WinConditionSystem.new())
	add_system(TimeLimitSystemScript.new())
	add_system(PostTickSystem.new())

# 添加系统
func add_system(system: ISimSystem) -> void:
	_systems.append(system)

# 执行所有系统
func execute_all(ctx: SimContext) -> void:
	for system in _systems:
		system.execute(ctx)

# 获取系统数量
func system_count() -> int:
	return _systems.size()
