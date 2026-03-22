# 角色：
# 仿真上下文，系统执行时的参数容器
#
# 读写边界：
# - 由 SimWorld 构造并传递给系统
# - 系统在此容器中读写状态
#
# 禁止事项：
# - 不得在此文件中写规则逻辑

class_name SimContext
extends RefCounted

# ====================
# 核心引用
# ====================

var config: SimConfig = null
var state: SimState = null
var queries: SimQueries = null
var events: SimEventBuffer = null
var rng: SimRng = null

# ====================
# Tick 相关
# ====================

var tick: int = 0

# ====================
# 输入
# ====================

var commands: InputFrame = null

# ====================
# 工作集
# ====================

var scratch: SimScratch = null
var worksets: SimWorksets = null

# ====================
# 初始化
# ====================

func _init() -> void:
	commands = InputFrame.new()
	scratch = SimScratch.new()
	worksets = SimWorksets.new()
