class_name BattleDepth
extends RefCounted

const ROW_STEP := 100
const WITHIN_ROW_STEP := 10
const SKY_ROW_STEP := ROW_STEP
const CANVAS_Z_MIN := -4096
const CANVAS_Z_MAX := 4096

const LAYER_PRIORITY_GROUND := 0
const LAYER_PRIORITY_FX := 1
const LAYER_PRIORITY_ACTOR := 2
const LAYER_PRIORITY_SURFACE := 3

const GROUND_Z_BIAS := 0
const SPAWN_MARKER_Z_BIAS := 1
const OCCLUDER_Z_BIAS := 0
const BUBBLE_Z_BIAS := 0
const EXPLOSION_Z_BIAS := 1
const ITEM_Z_BIAS := 2
const WorldMetrics = preload("res://gameplay/shared/world_metrics.gd")

const PLAYER_Z_BIAS := 0
const SURFACE_Z_BIAS := 5
const AIRBORNE_ITEM_BIAS := 120
const AIRCRAFT_BIAS := 100
const AIRCRAFT_ABOVE_WORLD_MARGIN := 100
const DEBUG_Z := 200

const DEFAULT_GROUND_MIN_Z := 0
const DEFAULT_SKY_MAX_Z := 3800
const UI_DOMAIN_MARGIN := 80
const SKY_AIR_ITEM_DELTA := 20
const SKY_GAP_MIN := 200
const GROUND_PEAK_PADDING := 64

static var _ground_min_z: int = DEFAULT_GROUND_MIN_Z
static var _sky_max_z: int = DEFAULT_SKY_MAX_Z


static func configure_depth_domains(ground_min_z: int, sky_max_z: int) -> void:
	_ground_min_z = clampi(ground_min_z, CANVAS_Z_MIN, CANVAS_Z_MAX)
	_sky_max_z = clampi(sky_max_z, CANVAS_Z_MIN, CANVAS_Z_MAX)


static func reset_depth_domains() -> void:
	_ground_min_z = DEFAULT_GROUND_MIN_Z
	_sky_max_z = DEFAULT_SKY_MAX_Z


static func get_depth_domains() -> Dictionary:
	return {
		"ground_min_z": _ground_min_z,
		"sky_max_z": _sky_max_z,
		"ui_min_z": ui_layer_z(),
	}


static func validate_depth_domains(map_height: int) -> Dictionary:
	var h := maxi(map_height, 1)
	var ground_peak := _ground_min_z + (h - 1) * ROW_STEP + LAYER_PRIORITY_SURFACE * WITHIN_ROW_STEP + GROUND_PEAK_PADDING
	var max_sky_item_offset := AIRCRAFT_BIAS + SKY_AIR_ITEM_DELTA + AIRBORNE_ITEM_BIAS
	var sky_floor := _sky_max_z - (h - 1) * SKY_ROW_STEP - max_sky_item_offset
	var gap := sky_floor - ground_peak
	return {
		"ok": gap >= SKY_GAP_MIN,
		"gap": gap,
		"ground_peak": ground_peak,
		"sky_floor": sky_floor,
		"ui_min_z": ui_layer_z(),
	}


static func _offset_z_bias(offset_y: int) -> int:
	return int(float(offset_y) / float(WorldMetrics.CELL_UNITS) * ROW_STEP)


static func ground_z(cell: Vector2i) -> int:
	return _safe_z(_floor_z(cell, GROUND_Z_BIAS))


static func spawn_marker_z(cell: Vector2i) -> int:
	return _safe_z(_floor_z(cell, SPAWN_MARKER_Z_BIAS))


static func occluder_z(cell: Vector2i) -> int:
	return _safe_z(_row_z(LAYER_PRIORITY_SURFACE, cell, OCCLUDER_Z_BIAS))


static func bubble_z(cell: Vector2i, z_bias: int = 0) -> int:
	return _safe_z(_row_z(LAYER_PRIORITY_FX, cell, BUBBLE_Z_BIAS + z_bias))


static func explosion_segment_z(cell: Vector2i, z_bias: int = 0) -> int:
	return _safe_z(_row_z(LAYER_PRIORITY_FX, cell, EXPLOSION_Z_BIAS + z_bias))


static func explosion_z(cell: Vector2i, z_bias: int = 0) -> int:
	return explosion_segment_z(cell, z_bias)


static func item_ground_z(cell: Vector2i, z_bias: int = 0) -> int:
	return _safe_z(_row_z(LAYER_PRIORITY_FX, cell, ITEM_Z_BIAS + z_bias))


static func item_z(cell: Vector2i, z_bias: int = 0) -> int:
	return item_ground_z(cell, z_bias)


static func player_z(cell: Vector2i, z_bias: int = 0, offset_y: int = 0) -> int:
	return _safe_z(_row_z(LAYER_PRIORITY_ACTOR, cell, PLAYER_Z_BIAS + z_bias + _offset_z_bias(offset_y)))


static func surface_z(cell: Vector2i, z_bias: int = 0) -> int:
	return _safe_z(_row_z(LAYER_PRIORITY_SURFACE, cell, SURFACE_Z_BIAS + z_bias))


static func item_airborne_z(from_cell: Vector2i, to_cell: Vector2i, z_bias: int = 0) -> int:
	var max_row := maxi(from_cell.y, to_cell.y)
	return _safe_z(_sky_row_z(max_row, AIRCRAFT_BIAS + SKY_AIR_ITEM_DELTA + AIRBORNE_ITEM_BIAS + z_bias))


static func item_airborne_z_from_world(from: Vector2, to: Vector2, cell_size: float, z_bias: int = 0) -> int:
	var safe_cell_size := maxf(cell_size, 1.0)
	var from_cell := Vector2i(int(floor(from.x / safe_cell_size)), int(floor(from.y / safe_cell_size)))
	var to_cell := Vector2i(int(floor(to.x / safe_cell_size)), int(floor(to.y / safe_cell_size)))
	return item_airborne_z(from_cell, to_cell, z_bias)


static func airplane_z(row_y: int, map_height: int = 0, z_bias: int = 0) -> int:
	var row_based := _sky_row_z(row_y, AIRCRAFT_BIAS + z_bias)
	if map_height <= 0:
		return _safe_z(row_based)
	var bottom_regular := _ground_min_z + (map_height - 1) * ROW_STEP + LAYER_PRIORITY_SURFACE * WITHIN_ROW_STEP
	return _safe_z(maxi(row_based, bottom_regular + AIRCRAFT_ABOVE_WORLD_MARGIN + z_bias))


static func debug_z(z_bias: int = 0) -> int:
	return _safe_z(_sky_max_z + DEBUG_Z + z_bias)


static func ui_layer_z() -> int:
	return _safe_z(_sky_max_z + UI_DOMAIN_MARGIN)


static func ui_z(z_bias: int = 0) -> int:
	return _safe_z(ui_layer_z() + z_bias)


static func _floor_z(cell: Vector2i, z_bias: int) -> int:
	return _ground_min_z - cell.x + z_bias


static func _row_z(layer_priority: int, cell: Vector2i, z_bias: int) -> int:
	return _ground_min_z + cell.y * ROW_STEP + layer_priority * WITHIN_ROW_STEP - cell.x + z_bias


static func _sky_row_z(row_y: int, z_bias: int) -> int:
	return _sky_max_z - row_y * SKY_ROW_STEP - z_bias


static func _safe_z(z: int) -> int:
	return clampi(z, CANVAS_Z_MIN, CANVAS_Z_MAX)
