# 角色：
# 静态格子，描述地图本体（墙、空地、砖块等）
#
# 读写边界：
# - 初始化时创建
# - 运行时不修改（除了机关等动态地形）
#
# 禁止事项：
# - 不得在此写规则逻辑

class_name CellStatic
extends RefCounted

# 基础地形类别
var tile_type: int = 0

# 规则判断的核心来源（优先看 flags）
var tile_flags: int = 0

# Phase38: 按方向表达通行能力，避免由表现贴图或命名推断规则。
var movement_pass_mask: int = TileConstants.PASS_ALL
var blast_pass_mask: int = TileConstants.PASS_ALL

# 如果该格是机制格，可用来索引具体机关类型
var mechanism_id: int = -1

# 地图主题或皮肤变体，供快照/校验稳定序列化使用
var theme_variant: int = 0

# 用于记录出生点组，后续多人模式/团队模式可用
var spawn_group_id: int = -1
