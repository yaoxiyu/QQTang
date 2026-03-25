extends Node

class_name TickRunner

const TICK_RATE: int = 20
const TICK_DT: float = 1.0 / float(TICK_RATE)

enum TickPhase {
	INPUT,
	MOVE,
	BUBBLE,
	EXPLOSION,
	COMBAT,
	ITEM,
	MODE,
	EVENT,
	SNAPSHOT,
}

var accumulator: float = 0.0
var current_tick: int = 0
var paused: bool = false
var phase_callbacks: Dictionary = {}
var tick_cost_usec: Dictionary = {}


func _ready() -> void:
	_init_phases()


func _process(delta: float) -> void:
	# Battle tick progression must be explicit and deterministic.
	# We intentionally do not drive combat from _process.
	var _delta := delta


func register_phase(phase: int, callback: Callable) -> void:
	if not phase_callbacks.has(phase):
		phase_callbacks[phase] = []
	phase_callbacks[phase].append(callback)


func step_one_tick() -> void:
	_run_tick()


func set_tick(tick: int) -> void:
	current_tick = tick


func rollback_to(tick: int) -> void:
	current_tick = max(0, tick)


func set_paused(value: bool) -> void:
	paused = value


func reset() -> void:
	accumulator = 0.0
	current_tick = 0
	tick_cost_usec.clear()
	_init_phases()


func get_phase_cost_usec(phase: int) -> int:
	return int(tick_cost_usec.get(phase, 0))


func _init_phases() -> void:
	phase_callbacks.clear()
	for phase in TickPhase.values():
		phase_callbacks[phase] = []


func _run_tick() -> void:
	current_tick += 1

	for phase in TickPhase.values():
		var started: int = Time.get_ticks_usec()
		var callbacks: Array = phase_callbacks.get(phase, [])
		for cb in callbacks:
			cb.call(current_tick)
		tick_cost_usec[phase] = Time.get_ticks_usec() - started
