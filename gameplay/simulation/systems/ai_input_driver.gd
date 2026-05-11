## DEV ONLY: Simple AI input driver for non-player peers.
## Generates random movement and periodic bomb placement.
## Not used in production flows.
class_name AiInputDriver
extends RefCounted

const PlayerInputFrameScript = preload("res://gameplay/simulation/input/player_input_frame.gd")

var _peer_id: int = -1
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _current_direction: Vector2i = Vector2i.ZERO
var _direction_ticks_remaining: int = 0
var _bomb_cooldown_ticks: int = 0
var _stuck_counter: int = 0
var _last_position: Vector2i = Vector2i(-1, -1)

# Configuration
var min_direction_ticks: int = 30
var max_direction_ticks: int = 90
var min_bomb_interval_ticks: int = 45
var max_bomb_interval_ticks: int = 120
var bomb_place_probability: float = 0.7


func configure(peer_id: int) -> void:
	_peer_id = peer_id
	_rng.randomize()
	_pick_new_direction()


func sample_input_for_tick(tick_id: int, _current_cell: Vector2i = Vector2i(-1, -1)) -> Dictionary:
	if _peer_id < 0:
		return _idle_input()

	if _direction_ticks_remaining <= 0:
		_pick_new_direction()
	_direction_ticks_remaining -= 1

	if _bomb_cooldown_ticks > 0:
		_bomb_cooldown_ticks -= 1

	var place_bomb := false
	if _bomb_cooldown_ticks <= 0:
		if _rng.randf() < bomb_place_probability:
			place_bomb = true
			_bomb_cooldown_ticks = _rng.randi_range(min_bomb_interval_ticks, max_bomb_interval_ticks)

	return {
		"move_x": _current_direction.x,
		"move_y": _current_direction.y,
		"action_bits": PlayerInputFrameScript.BIT_PLACE if place_bomb else 0,
	}


func notify_stuck() -> void:
	_stuck_counter += 1
	if _stuck_counter >= 3:
		_pick_new_direction()
		_stuck_counter = 0


func reset() -> void:
	_current_direction = Vector2i.ZERO
	_direction_ticks_remaining = 0
	_bomb_cooldown_ticks = _rng.randi_range(10, 30)
	_stuck_counter = 0
	_rng.randomize()
	_pick_new_direction()


func _pick_new_direction() -> void:
	var directions := [
		Vector2i(1, 0),
		Vector2i(-1, 0),
		Vector2i(0, 1),
		Vector2i(0, -1),
		Vector2i(0, 0),
	]
	_current_direction = directions[_rng.randi_range(0, directions.size() - 1)]
	_direction_ticks_remaining = _rng.randi_range(min_direction_ticks, max_direction_ticks)


func _idle_input() -> Dictionary:
	return {"move_x": 0, "move_y": 0, "action_bits": 0}
