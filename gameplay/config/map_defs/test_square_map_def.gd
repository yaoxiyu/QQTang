extends RefCounted
class_name TestSquareMapDef

static func build() -> Dictionary:
    return {
        "map_id": "test_square",
        "display_name": "测试方形图",
        "width": 13,
        "height": 11,
        "tile_size": 32,
        "spawn_points": [
            Vector2i(1, 1),
            Vector2i(11, 9)
        ],
        "static_blocks": [
            Vector2i(2, 2),
            Vector2i(4, 2),
            Vector2i(6, 2),
            Vector2i(8, 2),
            Vector2i(10, 2),
            Vector2i(2, 4),
            Vector2i(4, 4),
            Vector2i(6, 4),
            Vector2i(8, 4),
            Vector2i(10, 4),
            Vector2i(2, 6),
            Vector2i(4, 6),
            Vector2i(6, 6),
            Vector2i(8, 6),
            Vector2i(10, 6),
            Vector2i(2, 8),
            Vector2i(4, 8),
            Vector2i(6, 8),
            Vector2i(8, 8),
            Vector2i(10, 8)
        ],
        "breakable_blocks": [
            Vector2i(3, 1),
            Vector2i(5, 1),
            Vector2i(7, 1),
            Vector2i(9, 1),
            Vector2i(1, 3),
            Vector2i(3, 3),
            Vector2i(5, 3),
            Vector2i(7, 3),
            Vector2i(9, 3),
            Vector2i(11, 3),
            Vector2i(1, 5),
            Vector2i(3, 5),
            Vector2i(5, 5),
            Vector2i(7, 5),
            Vector2i(9, 5),
            Vector2i(11, 5)
        ]
    }
