class_name WorldSnapshot
extends RefCounted

var tick_id: int = 0
var rng_state: int = 0
var players: Array[Dictionary] = []
var bubbles: Array[Dictionary] = []
var items: Array[Dictionary] = []
var walls: Array[Dictionary] = []
var breakable_blocks_remaining: int = -1
var item_pool_runtime: Dictionary = {}
var match_state: Dictionary = {}
var mode_state: Dictionary = {}
var checksum: int = 0


func duplicate_deep() -> WorldSnapshot:
	var copy := WorldSnapshot.new()
	copy.tick_id = tick_id
	copy.rng_state = rng_state
	copy.players = players.duplicate(true)
	copy.bubbles = bubbles.duplicate(true)
	copy.items = items.duplicate(true)
	copy.walls = walls.duplicate(true)
	copy.breakable_blocks_remaining = breakable_blocks_remaining
	copy.item_pool_runtime = item_pool_runtime.duplicate(true)
	copy.match_state = match_state.duplicate(true)
	copy.mode_state = mode_state.duplicate(true)
	copy.checksum = checksum
	return copy
