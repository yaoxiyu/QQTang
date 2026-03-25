# 角色：
# 配置数据，描述本局固定规则参数
#
# 读写边界：
# - 只在 SimulationRunner 初始化时被写入
# - 可在任何系统中被只读访问
#
# 禁止事项：
# - 不得存放随 Tick 变化的数据

class_name SimConfig
extends RefCounted

# 对局配置
var tick_rate: int = 20
var map_def: Resource = null
var mode_def: Resource = null

# 玩家配置
var player_defs: Array[Resource] = []

# 道具配置
var item_defs: Dictionary = {}

# 泡泡配置
var bubble_defs: Dictionary = {}

# 系统标志
var system_flags: Dictionary = {}
