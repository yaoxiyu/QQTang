# 角色：
# 测试地图工厂，通过字符串模板构造 GridState
#
# 读写边界：
# - 只在测试/初始化时调用
#
# 禁止事项：
# - 不得在此写规则逻辑

class_name TestMapFactory
extends RefCounted

# ====================
# 地图构造方法
# ====================

static func build_basic_map() -> GridState:
	var rows: Array[String] = [
		"#############",
		"#S..B...B..S#",
		"#.#B#B#B#B#.#",
		"#B..B.B.B..B#",
		"#.#.#...#.#.#",
		"#..B..M..B..#",
		"#.#.#...#.#.#",
		"#B..B.B.B..B#",
		"#.#B#B#B#B#.#",
		"#S..B...B..S#",
		"#############",
	]

	return _build_from_rows(rows)

static func _build_from_rows(rows: Array[String]) -> GridState:
	var height := rows.size()
	var width := rows[0].length()

	var grid := GridState.new()
	grid.initialize(width, height)

	for y in range(height):
		var row := rows[y]
		for x in range(width):
			var c := row.unicode_at(x)

			match c:
				35: # # -> SOLID_WALL
					grid.set_static_cell(x, y, TileFactory.make_solid_wall())
				66: # B -> BREAKABLE_BLOCK
					grid.set_static_cell(x, y, TileFactory.make_breakable_block())
				83: # S -> SPAWN
					grid.set_static_cell(x, y, TileFactory.make_spawn())
				77: # M -> MECHANISM
					grid.set_static_cell(x, y, TileFactory.make_mechanism())
				46: # . -> EMPTY
					grid.set_static_cell(x, y, TileFactory.make_empty())
				_:
					push_error("Unknown map char at (%d, %d): %d" % [x, y, c])
					grid.set_static_cell(x, y, TileFactory.make_empty())

	return grid
