# 角色：
# 地图网格状态，包含静态砖块和动态占用信息
#
# 读写边界：
# - 只在 DestructibleSystem 中被写入
# - 可在任何查询系统中被读取
#
# 禁止事项：
# - 不得在此文件中写填充算法或规则逻辑

class_name GridState
extends RefCounted

# 网格尺寸
var width: int = 0
var height: int = 0

# 静态格子数组（使用 CellStatic）
var static_cells: Array[CellStatic] = []

# 动态格子数组（使用 CellDynamic）
var dynamic_cells: Array[CellDynamic] = []

# ====================
# 初始化方法
# ====================

# 初始化网格尺寸
func initialize(p_width: int, p_height: int) -> void:
	width = p_width
	height = p_height
	_resize_internal()

# 调整内部数组大小
func _resize_internal() -> void:
	var total = width * height
	static_cells.resize(total)
	dynamic_cells.resize(total)
	for i in range(total):
		static_cells[i] = TileFactory.make_empty()
		dynamic_cells[i] = CellDynamic.new()

# ====================
# 辅助方法
# ====================

# 计算格子索引
func to_cell_index(cell_x: int, cell_y: int) -> int:
	return cell_y * width + cell_x

# 边界检查
func is_in_bounds(cell_x: int, cell_y: int) -> bool:
	return cell_x >= 0 and cell_x < width and cell_y >= 0 and cell_y < height

# ====================
# 格子访问
# ====================

# 获取静态格子
func get_static_cell(cell_x: int, cell_y: int) -> CellStatic:
	if not is_in_bounds(cell_x, cell_y):
		return TileFactory.make_empty()
	return static_cells[to_cell_index(cell_x, cell_y)]

# 获取动态格子
func get_dynamic_cell(cell_x: int, cell_y: int) -> CellDynamic:
	if not is_in_bounds(cell_x, cell_y):
		return CellDynamic.new()
	return dynamic_cells[to_cell_index(cell_x, cell_y)]

# 设置静态格子
func set_static_cell(cell_x: int, cell_y: int, cell: CellStatic) -> void:
	if not is_in_bounds(cell_x, cell_y):
		return
	static_cells[to_cell_index(cell_x, cell_y)] = cell

# 设置动态格子
func set_dynamic_cell(cell_x: int, cell_y: int, cell: CellDynamic) -> void:
	if not is_in_bounds(cell_x, cell_y):
		return
	dynamic_cells[to_cell_index(cell_x, cell_y)] = cell

# 清空动态信息（用于 PreTick）
func clear_dynamic() -> void:
	for i in range(width * height):
		dynamic_cells[i].bubble_id = -1
		dynamic_cells[i].item_id = -1
		dynamic_cells[i].explosion_flags = 0
