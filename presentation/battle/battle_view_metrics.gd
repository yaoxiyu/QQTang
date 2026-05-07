class_name BattleViewMetrics
extends RefCounted

const WorldMetrics = preload("res://gameplay/shared/world_metrics.gd")

const DEFAULT_CELL_PIXELS := WorldMetrics.DEFAULT_CELL_PIXELS
const OCCLUDER_PLAYER_SAMPLE_SIZE_RATIO := Vector2(20.0 / DEFAULT_CELL_PIXELS, 28.0 / DEFAULT_CELL_PIXELS)
const ITEM_HALF_SIZE_RATIO := 10.0 / DEFAULT_CELL_PIXELS
const PLAYER_BODY_HEIGHT_RATIO := 2.0


static func player_sample_size(cell_pixels: float = DEFAULT_CELL_PIXELS) -> Vector2:
	return OCCLUDER_PLAYER_SAMPLE_SIZE_RATIO * cell_pixels


static func item_half_size_px(cell_pixels: float = DEFAULT_CELL_PIXELS) -> float:
	return cell_pixels * ITEM_HALF_SIZE_RATIO


static func player_body_scale(cell_pixels: float, source_frame_height: float) -> float:
	return 1.0
