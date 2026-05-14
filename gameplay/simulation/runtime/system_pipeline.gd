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
const ExplosionHitSystemScript = preload("res://gameplay/simulation/systems/explosion_hit_system.gd")
const PlayerLifeTransitionSystemScript = preload("res://gameplay/simulation/systems/player_life_transition_system.gd")
const JellyInteractionSystemScript = preload("res://gameplay/simulation/systems/jelly_interaction_system.gd")
const RespawnSystemScript = preload("res://gameplay/simulation/systems/respawn_system.gd")
const ScoreSystemScript = preload("res://gameplay/simulation/systems/score_system.gd")
const DeathPresentationSystemScript = preload("res://gameplay/simulation/systems/death_presentation_system.gd")
const ItemPoolSystemScript = preload("res://gameplay/simulation/systems/item_pool_system.gd")

# 系统列表
var _systems: Array[ISimSystem] = []

# ====================
# 核心方法
# ====================

# 初始化默认系统管线
func initialize_default_pipeline() -> void:
	_systems.clear()

	# 按固定顺序添加系统
	# ExplosionHit -> JellyInteraction -> PlayerLifeTransition 确保所有死亡/被困
	# 状态在一个 PLTS 调用中统一处理，避免两次注册的竞态
	add_system(PreTickSystem.new())
	add_system(InputSystem.new())
	add_system(MovementSystem.new())
	add_system(BubblePlacementSystem.new())
	add_system(BombFuseSystem.new())
	add_system(ExplosionResolveSystem.new())
	add_system(ExplosionHitSystemScript.new())
	add_system(JellyInteractionSystemScript.new())
	add_system(PlayerLifeTransitionSystemScript.new())
	add_system(DeathPresentationSystemScript.new())
	add_system(RespawnSystemScript.new())
	add_system(ScoreSystemScript.new())
	add_system(StatusEffectSystem.new())
	add_system(ItemSpawnSystem.new())
	add_system(ItemPoolSystemScript.new())
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
