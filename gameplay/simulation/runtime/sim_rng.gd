# 角色：
# 仿真随机数生成器，确保可复现性
#
# 读写边界：
# - 只在系统中被调用
# - 不得直接调用 Godot 的 randi() 等函数
#
# 禁止事项：
# - 不得使用 Godot 内置随机数

class_name SimRng
extends RefCounted

# 当前种子
var _seed: int = 0

# ====================
# 构造函数
# ====================

func _init(p_seed: int = 12345):
	_seed = p_seed

# ====================
# 核心方法
# ====================

# 生成下一个随机数（mulberry32 算法）
func next() -> int:
	_seed ^= _seed >> 12
	_seed ^= _seed << 25
	_seed ^= _seed >> 27
	return (_seed * 2685821657736338717) >> 32

# 生成 [0, max) 范围的随机数
func next_int(_max: int) -> int:
	if _max <= 0:
		push_warning("SimRng.next_int called with non-positive max: %d" % _max)
		return 0
	return next() % _max

# 生成 [min, max] 范围的随机数
func next_int_range(_min: int, _max: int) -> int:
	if _max < _min:
		push_warning("SimRng.next_int_range invalid bounds: [%d, %d]" % [_min, _max])
		return _min
	return _min + next() % (_max - _min + 1)

# 生成 bool 值
func next_bool() -> bool:
	return next() % 2 == 0

# 重新设置种子
func seed(new_seed: int) -> void:
	_seed = new_seed
