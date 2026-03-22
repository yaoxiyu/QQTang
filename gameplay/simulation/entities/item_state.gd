# 角色：
# 道具状态，包含道具的所有属性
#
# 读写边界：
# - 只在 ItemSpawnSystem/ ItemPickupSystem 中被写入
# - 可在任何查询系统中被读取
#
# 禁止事项：
# - 不得在此文件中写规则逻辑

class_name ItemState
extends RefCounted

# ====================
# 实体标识
# ====================
var entity_id: int = 0
var generation: int = 0

# ====================
# 基本属性
# ====================
var alive: bool = true
var item_type: int = 0

# ====================
# 位置
# ====================
var cell_x: int = 0
var cell_y: int = 0

# ====================
# 生命周期
# ====================
var spawn_tick: int = 0
var pickup_delay_ticks: int = 0  # 拾取延迟（防止刚生成就拾取）

# ====================
# 渲染控制
# ====================
var visible: bool = true
