class_name Phase2SandboxMapFactory
extends RefCounted


static func build_large_map() -> GridState:
	var rows: Array[String] = [
		"#############",
		"#S..B...B..S#",
		"#.B.#B#B#.B.#",
		"#..B.....B..#",
		"#B#.#B#B#.#B#",
		"#...B...B...#",
		"#B#.#B#B#.#B#",
		"#..B.....B..#",
		"#.B.#B#B#.B.#",
		"#S..B...B..S#",
		"#############"
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
				35:
					grid.set_static_cell(x, y, TileFactory.make_solid_wall())
				66:
					grid.set_static_cell(x, y, TileFactory.make_breakable_block())
				83:
					grid.set_static_cell(x, y, TileFactory.make_spawn())
				46:
					grid.set_static_cell(x, y, TileFactory.make_empty())
				_:
					grid.set_static_cell(x, y, TileFactory.make_empty())

	return grid
