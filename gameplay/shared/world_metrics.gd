class_name WorldMetrics
extends RefCounted

const CELL_UNITS : int = 1000
const HALF_CELL_UNITS : int = CELL_UNITS / 2
const QUARTER_CELL_UNITS : int = CELL_UNITS / 4
const FIFTH_CELL_UNITS : int = CELL_UNITS / 5
const SIXTH_CELL_UNITS : int = CELL_UNITS / 6
const EIGHTH_CELL_UNITS : int = CELL_UNITS / 8
const TENTH_CELL_UNITS : int = CELL_UNITS / 10

const DEFAULT_CELL_PIXELS := 40.0


static func sim_units_to_pixels(sim_units: float, cell_pixels: float = DEFAULT_CELL_PIXELS) -> float:
	return (sim_units / float(CELL_UNITS)) * cell_pixels
