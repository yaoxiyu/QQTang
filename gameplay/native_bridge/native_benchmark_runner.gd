class_name NativeBenchmarkRunner
extends RefCounted

const NativeFeatureFlagsScript = preload("res://gameplay/native_bridge/native_feature_flags.gd")
const NativeKernelRuntimeScript = preload("res://gameplay/native_bridge/native_kernel_runtime.gd")

const MAX_ALLOWED_SLOWDOWN_RATIO_BY_BENCH := {
	"checksum": 3.0,
	"movement": 4.0,
	"explosion": 4.0,
}


func run_checksum_benchmark(iterations: int = 8) -> Dictionary:
	var baseline_samples: Array[float] = []
	var native_samples: Array[float] = []
	var baseline_builder := ChecksumBuilder.new()
	var native_bridge := NativeChecksumBridge.new()
	var parity_ok := true

	for iteration in range(maxi(iterations, 1)):
		var world := _build_world(4100 + iteration)
		var tick_id := world.state.match_state.tick
		var baseline_checksum := 0
		var native_checksum := 0
		var started := Time.get_ticks_usec()
		baseline_checksum = baseline_builder.build(world, tick_id)
		baseline_samples.append(float(Time.get_ticks_usec() - started))
		started = Time.get_ticks_usec()
		native_checksum = native_bridge.build(world, tick_id)
		native_samples.append(float(Time.get_ticks_usec() - started))
		parity_ok = parity_ok and native_checksum == baseline_checksum
		world.dispose()

	return _build_report(
		"checksum",
		baseline_samples,
		native_samples,
		parity_ok,
		NativeKernelRuntimeScript.get_checksum_kernel() != null
	)


func run_movement_benchmark(iterations: int = 4) -> Dictionary:
	var baseline_samples: Array[float] = []
	var native_samples: Array[float] = []
	var parity_ok := true
	for iteration in range(maxi(iterations, 1)):
		var seed := 5100 + iteration
		var baseline_result := _measure_movement_sequence(false, seed)
		var native_result := _measure_movement_sequence(true, seed)
		baseline_samples.append(float(baseline_result.get("elapsed_usec", 0.0)))
		native_samples.append(float(native_result.get("elapsed_usec", 0.0)))
		parity_ok = parity_ok and _movement_results_equal(baseline_result, native_result)
	return _build_report(
		"movement",
		baseline_samples,
		native_samples,
		parity_ok,
		NativeKernelRuntimeScript.get_movement_kernel() != null
	)


func run_explosion_benchmark(iterations: int = 4) -> Dictionary:
	var baseline_samples: Array[float] = []
	var native_samples: Array[float] = []
	var parity_ok := true
	for iteration in range(maxi(iterations, 1)):
		var seed := 7100 + iteration
		var baseline_result := _measure_explosion_sequence(false, seed)
		var native_result := _measure_explosion_sequence(true, seed)
		baseline_samples.append(float(baseline_result.get("elapsed_usec", 0.0)))
		native_samples.append(float(native_result.get("elapsed_usec", 0.0)))
		parity_ok = parity_ok and _explosion_results_equal(baseline_result, native_result)
	return _build_report(
		"explosion",
		baseline_samples,
		native_samples,
		parity_ok,
		NativeKernelRuntimeScript.get_explosion_kernel() != null
	)


func _measure_movement_sequence(use_native: bool, seed: int) -> Dictionary:
	var previous_flag := NativeFeatureFlagsScript.enable_native_movement
	NativeFeatureFlagsScript.enable_native_movement = use_native
	var world := _build_world(seed)
	var player := world.state.players.get_player(int(world.state.players.active_ids[0]))
	player.speed_level = 3
	world.state.players.update_player(player)
	var command_sequence := [
		Vector2i.RIGHT,
		Vector2i.RIGHT,
		Vector2i.RIGHT,
		Vector2i.RIGHT,
		Vector2i.RIGHT,
		Vector2i.RIGHT,
		Vector2i.UP,
	]
	var started := Time.get_ticks_usec()
	for command in command_sequence:
		var input_frame := InputFrame.new()
		input_frame.tick = world.state.match_state.tick + 1
		var player_command := PlayerCommand.neutral()
		player_command.move_x = command.x
		player_command.move_y = command.y
		input_frame.set_command(player.player_slot, player_command)
		world.enqueue_input(input_frame)
		world.step()
	var result := {
		"elapsed_usec": float(Time.get_ticks_usec() - started),
		"players": SnapshotService.new().build_light_snapshot(world, world.state.match_state.tick).players,
		"bubbles": SnapshotService.new().build_light_snapshot(world, world.state.match_state.tick).bubbles,
	}
	world.dispose()
	NativeFeatureFlagsScript.enable_native_movement = previous_flag
	return result


func _measure_explosion_sequence(use_native: bool, seed: int) -> Dictionary:
	var previous_flag := NativeFeatureFlagsScript.enable_native_explosion
	NativeFeatureFlagsScript.enable_native_explosion = use_native
	var world := _build_world(seed)
	_configure_explosion_scenario(world)
	world.events.begin_tick(1)

	var ctx := SimContext.new()
	ctx.config = world.config
	ctx.state = world.state
	ctx.queries = world.queries
	ctx.events = world.events
	ctx.rng = world.rng
	ctx.tick = 1
	ctx.scratch = SimScratch.new()
	ctx.scratch.bubbles_to_explode = [1]

	var resolve_system := ExplosionResolveSystem.new()
	var hit_system := ExplosionHitSystem.new()
	var started := Time.get_ticks_usec()
	resolve_system.execute(ctx)
	hit_system.execute(ctx)
	var result := {
		"elapsed_usec": float(Time.get_ticks_usec() - started),
		"processed_bubble_ids": _sorted_int_keys(ctx.scratch.processed_explosion_bubble_ids),
		"queued_chain_bubble_ids": _sorted_int_keys(ctx.scratch.queued_chain_bubble_ids),
		"destroy_cells": _serialize_cells(ctx.scratch.cells_to_destroy),
		"exploded_bubble_ids": _serialize_int_array(ctx.scratch.exploded_bubble_ids),
		"players_to_kill": _serialize_int_array(ctx.scratch.players_to_kill),
		"players_to_trap": _serialize_int_array(ctx.scratch.players_to_trap),
		"players_to_execute": _serialize_int_array(ctx.scratch.players_to_execute),
		"hit_entries": _serialize_hit_entries(ctx.scratch.explosion_hit_entries),
		"events": _serialize_events(ctx.events.get_events()),
	}
	world.dispose()
	NativeFeatureFlagsScript.enable_native_explosion = previous_flag
	return result


func _build_world(seed: int) -> SimWorld:
	var world := SimWorld.new()
	world.rng = SimRng.new(seed)
	world.bootstrap(SimConfig.new(), {"grid": BuiltinMapFactory.build_basic_map()})
	return world


func _configure_explosion_scenario(world: SimWorld) -> void:
	var source_player_id := int(world.state.players.active_ids[0])
	var target_player_id := int(world.state.players.active_ids[1])

	var target_player := world.state.players.get_player(target_player_id)
	target_player.cell_x = 6
	target_player.cell_y = 4
	world.state.players.update_player(target_player)

	var source_bubble_id := world.state.bubbles.spawn_bubble(source_player_id, 6, 5, 4, 1)
	var chain_bubble_id := world.state.bubbles.spawn_bubble(source_player_id, 8, 5, 1, 1)
	var source_bubble := world.state.bubbles.get_bubble(source_bubble_id)
	var chain_bubble := world.state.bubbles.get_bubble(chain_bubble_id)
	source_bubble.owner_player_id = source_player_id
	chain_bubble.owner_player_id = source_player_id
	world.state.bubbles.update_bubble(source_bubble)
	world.state.bubbles.update_bubble(chain_bubble)

	world.state.items.spawn_item(3, 6, 6, 0)
	world.state.indexes.rebuild_from_state(world.state)


func _build_report(
	name: String,
	baseline_samples: Array[float],
	native_samples: Array[float],
	parity_ok: bool,
	native_runtime_available: bool
) -> Dictionary:
	var baseline_avg := _average(baseline_samples)
	var native_avg := _average(native_samples)
	var slowdown_ratio := 0.0
	var max_allowed_slowdown_ratio := float(MAX_ALLOWED_SLOWDOWN_RATIO_BY_BENCH.get(name, 3.0))
	if baseline_avg > 0.0:
		slowdown_ratio = native_avg / baseline_avg
	return {
		"name": name,
		"sample_count": mini(baseline_samples.size(), native_samples.size()),
		"baseline_avg_usec": baseline_avg,
		"native_avg_usec": native_avg,
		"baseline_p95_usec": _p95(baseline_samples),
		"native_p95_usec": _p95(native_samples),
		"baseline_max_usec": _maximum(baseline_samples),
		"native_max_usec": _maximum(native_samples),
		"parity_ok": parity_ok,
		"native_runtime_available": native_runtime_available,
		"slowdown_ratio": slowdown_ratio,
		"max_allowed_slowdown_ratio": max_allowed_slowdown_ratio,
	}


func _average(samples: Array[float]) -> float:
	if samples.is_empty():
		return 0.0
	var total := 0.0
	for sample in samples:
		total += sample
	return total / float(samples.size())


func _maximum(samples: Array[float]) -> float:
	var max_value := 0.0
	for sample in samples:
		max_value = maxf(max_value, sample)
	return max_value


func _p95(samples: Array[float]) -> float:
	if samples.is_empty():
		return 0.0
	var sorted := samples.duplicate()
	sorted.sort()
	var index := mini(int(ceil(float(sorted.size()) * 0.95)) - 1, sorted.size() - 1)
	return float(sorted[maxi(index, 0)])


func _movement_results_equal(a: Dictionary, b: Dictionary) -> bool:
	return a.get("players", []) == b.get("players", []) and a.get("bubbles", []) == b.get("bubbles", [])


func _explosion_results_equal(a: Dictionary, b: Dictionary) -> bool:
	return (
		a.get("processed_bubble_ids", []) == b.get("processed_bubble_ids", [])
		and a.get("queued_chain_bubble_ids", []) == b.get("queued_chain_bubble_ids", [])
		and a.get("destroy_cells", []) == b.get("destroy_cells", [])
		and a.get("exploded_bubble_ids", []) == b.get("exploded_bubble_ids", [])
		and a.get("players_to_kill", []) == b.get("players_to_kill", [])
		and a.get("players_to_trap", []) == b.get("players_to_trap", [])
		and a.get("players_to_execute", []) == b.get("players_to_execute", [])
		and a.get("hit_entries", []) == b.get("hit_entries", [])
		and a.get("events", []) == b.get("events", [])
	)


func _serialize_cells(cells: Array[Vector2i]) -> Array[Dictionary]:
	var serialized: Array[Dictionary] = []
	for cell in cells:
		serialized.append({"cell_x": cell.x, "cell_y": cell.y})
	return serialized


func _serialize_hit_entries(entries: Array) -> Array[Dictionary]:
	var serialized: Array[Dictionary] = []
	for raw_entry in entries:
		var entry: ExplosionHitEntry = raw_entry
		if entry == null:
			continue
		serialized.append({
			"source_bubble_id": entry.source_bubble_id,
			"source_player_id": entry.source_player_id,
			"source_cell_x": entry.source_cell_x,
			"source_cell_y": entry.source_cell_y,
			"target_type": entry.target_type,
			"target_entity_id": entry.target_entity_id,
			"target_cell_x": entry.target_cell_x,
			"target_cell_y": entry.target_cell_y,
			"target_aux_data": entry.target_aux_data.duplicate(true),
		})
	return serialized


func _serialize_events(events: Array) -> Array[Dictionary]:
	var serialized: Array[Dictionary] = []
	for raw_event in events:
		if raw_event == null:
			continue
		serialized.append({
			"event_type": int(raw_event.event_type),
			"payload": (raw_event.payload as Dictionary).duplicate(true),
		})
	return serialized


func _sorted_int_keys(values: Dictionary) -> Array[int]:
	var result: Array[int] = []
	for key in values.keys():
		result.append(int(key))
	result.sort()
	return result


func _serialize_int_array(values: Array[int]) -> Array[int]:
	var copied := values.duplicate()
	copied.sort()
	return copied
