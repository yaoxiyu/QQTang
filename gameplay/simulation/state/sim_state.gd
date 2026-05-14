# 角色：
# 仿真状态根对象，持有整个仿真唯一真相状态
#
# 读写边界：
# - 只在 SimWorld.step() 中被写入
# - 可在任何系统中通过 SimContext 读取
#
# 禁止事项：
# - 不得在此文件中写规则逻辑

class_name SimState
extends RefCounted

# ====================
# 核心状态对象
# ====================

# 对局状态
var match_state: MatchState = MatchState.new()

# 地图网格
var grid: GridState = GridState.new()

# 实体存储
var players: PlayerStore = PlayerStore.new()
var bubbles: BubbleStore = BubbleStore.new()
var items: ItemStore = ItemStore.new()

# 模式运行时状态
var mode: ModeState = ModeState.new()

# 道具池运行时状态
var item_pool_runtime: RefCounted = null

# 运行时标志
var runtime_flags: RuntimeFlags = RuntimeFlags.new()

# 索引结构
var indexes: SimIndexes = SimIndexes.new()

# ====================
# 初始化方法
# ====================

# 初始化默认状态
func initialize_default() -> void:
	match_state.reset()
	grid.clear_dynamic()
	players.clear()
	bubbles.clear()
	items.clear()
	mode.reset()
	runtime_flags.reset()
	indexes.clear()

# 重置对局状态（保留配置）
func reset_match() -> void:
	match_state.reset()
	grid.clear_dynamic()
	players.clear()
	bubbles.clear()
	items.clear()
	mode.reset()
	indexes.clear()
