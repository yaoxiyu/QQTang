extends "res://tests/gut/base/qqt_unit_test.gd"

const NativeFeatureFlagsScript = preload("res://gameplay/native_bridge/native_feature_flags.gd")
const NativeKernelRuntimeScript = preload("res://gameplay/native_bridge/native_kernel_runtime.gd")


func test_main() -> void:
	var ok := true
	ok = _test_placement_uses_bubble_loadout_and_indexes_footprint() and ok
	ok = _test_type2_power2_explosion_covers_square_area() and ok
	ok = _test_type2_power2_native_matches_gdscript() and ok
	ok = _test_snapshot_and_checksum_include_bubble_metadata() and ok


func _test_placement_uses_bubble_loadout_and_indexes_footprint() -> bool:
	var world := _build_world_with_bubble_loadout(2, 2, 4)
	var player := _move_player_to(world, 0, 4, 4)
	_place_bubble(world, player.player_slot)

	var bubble := world.state.bubbles.get_bubble(world.state.bubbles.active_ids[0])
	var prefix := "bubble_gameplay_metadata_test"
	var ok := true
	ok = qqt_check(bubble.bubble_type == 2, "placed bubble should copy type from loadout", prefix) and ok
	ok = qqt_check(bubble.power == 2, "placed bubble should copy power from loadout", prefix) and ok
	ok = qqt_check(bubble.footprint_cells == 4, "placed bubble should copy footprint from loadout", prefix) and ok
	ok = qqt_check(world.queries.get_bubble_at(4, 4) == bubble.entity_id, "footprint origin should be indexed", prefix) and ok
	ok = qqt_check(world.queries.get_bubble_at(5, 4) == bubble.entity_id, "footprint right cell should be indexed", prefix) and ok
	ok = qqt_check(world.queries.get_bubble_at(4, 5) == bubble.entity_id, "footprint lower cell should be indexed", prefix) and ok
	ok = qqt_check(world.queries.get_bubble_at(5, 5) == bubble.entity_id, "footprint diagonal cell should be indexed", prefix) and ok
	ok = qqt_check(world.queries.is_move_blocked_for_player(int(world.state.players.active_ids[1]), 5, 5), "footprint indexed cell should block other players", prefix) and ok
	world.dispose()
	return ok


func _test_type2_power2_explosion_covers_square_area() -> bool:
	var world := _build_world_with_bubble_loadout(2, 2, 4)
	var attacker := _move_player_to(world, 0, 4, 4)
	var victim := _move_player_to(world, 1, 7, 7)
	_place_bubble(world, attacker.player_slot)
	var bubble := world.state.bubbles.get_bubble(world.state.bubbles.active_ids[0])
	bubble.explode_tick = world.state.match_state.tick + 1
	world.state.bubbles.update_bubble(bubble)

	var result := world.step()
	var exploded_event := _find_event(result["events"], SimEvent.EventType.BUBBLE_EXPLODED)
	var victim_after := world.state.players.get_player(victim.entity_id)
	var covered_cells: Array = exploded_event.payload.get("covered_cells", []) if exploded_event != null else []
	var prefix := "bubble_gameplay_metadata_test"
	var ok := true
	ok = qqt_check(exploded_event != null, "type2 bubble should explode", prefix) and ok
	ok = qqt_check(covered_cells.has(Vector2i(2, 2)), "power2 square should include top-left margin cell", prefix) and ok
	ok = qqt_check(covered_cells.has(Vector2i(7, 7)), "power2 square should include bottom-right margin cell", prefix) and ok
	ok = qqt_check(victim_after != null and not victim_after.alive, "victim inside type2 6x6 should be killed", prefix) and ok
	ok = qqt_check(world.queries.get_bubble_at(5, 5) == -1, "exploded footprint indexes should be cleared", prefix) and ok
	world.dispose()
	return ok


func _test_type2_power2_native_matches_gdscript() -> bool:
	if not NativeKernelRuntimeScript.is_available() or not NativeKernelRuntimeScript.has_explosion_kernel():
		pending("native explosion kernel is not available")
		return true

	var previous_native_explosion := NativeFeatureFlagsScript.enable_native_explosion
	var baseline_world := _build_world_with_bubble_loadout(2, 2, 4)
	var native_world := _build_world_with_bubble_loadout(2, 2, 4)
	var baseline_event := _explode_type2_power2_with_native_flag(baseline_world, false)
	var native_event := _explode_type2_power2_with_native_flag(native_world, true)
	NativeFeatureFlagsScript.enable_native_explosion = previous_native_explosion

	var prefix := "bubble_gameplay_metadata_test.native_parity"
	var ok := true
	ok = qqt_check(baseline_event != null and native_event != null, "both paths should emit explosion event", prefix) and ok
	ok = qqt_check(
		_sort_cells(baseline_event.payload.get("covered_cells", [])) == _sort_cells(native_event.payload.get("covered_cells", [])),
		"type2 power2 native coverage should match GDScript",
		prefix
	) and ok
	ok = qqt_check(
		baseline_world.queries.get_bubble_at(5, 5) == native_world.queries.get_bubble_at(5, 5),
		"native and GDScript should both clear footprint indexes",
		prefix
	) and ok
	baseline_world.dispose()
	native_world.dispose()
	return ok


func _test_snapshot_and_checksum_include_bubble_metadata() -> bool:
	var world := _build_world_with_bubble_loadout(2, 2, 4)
	var player := _move_player_to(world, 0, 4, 4)
	_place_bubble(world, player.player_slot)
	var snapshot_service := SnapshotService.new()
	var snapshot := snapshot_service.build_standard_snapshot(world, world.state.match_state.tick)
	var bubble_data: Dictionary = snapshot.bubbles[0]
	var checksum_builder := ChecksumBuilder.new()
	var checksum_before := checksum_builder.build(world, world.state.match_state.tick)
	var bubble := world.state.bubbles.get_bubble(world.state.bubbles.active_ids[0])
	bubble.footprint_cells = 1
	world.state.bubbles.update_bubble(bubble)
	var checksum_after := checksum_builder.build(world, world.state.match_state.tick)

	var restored := _build_world_with_bubble_loadout(1, 1, 1)
	snapshot_service.restore_snapshot(restored, snapshot)
	var restored_bubble := restored.state.bubbles.get_bubble(restored.state.bubbles.active_ids[0])
	var prefix := "bubble_gameplay_metadata_test"
	var ok := true
	ok = qqt_check(int(bubble_data.get("bubble_type", 0)) == 2, "snapshot should include bubble_type", prefix) and ok
	ok = qqt_check(int(bubble_data.get("power", 0)) == 2, "snapshot should include power", prefix) and ok
	ok = qqt_check(int(bubble_data.get("footprint_cells", 0)) == 4, "snapshot should include footprint_cells", prefix) and ok
	ok = qqt_check(checksum_before != checksum_after, "checksum should change when footprint changes", prefix) and ok
	ok = qqt_check(restored_bubble != null and restored_bubble.footprint_cells == 4, "restore should preserve footprint", prefix) and ok
	world.dispose()
	restored.dispose()
	return ok


func _explode_type2_power2_with_native_flag(world: SimWorld, use_native: bool) -> SimEvent:
	NativeFeatureFlagsScript.enable_native_explosion = use_native
	var attacker := _move_player_to(world, 0, 4, 4)
	_move_player_to(world, 1, 7, 7)
	_place_bubble(world, attacker.player_slot)
	var bubble := world.state.bubbles.get_bubble(world.state.bubbles.active_ids[0])
	bubble.explode_tick = world.state.match_state.tick + 1
	world.state.bubbles.update_bubble(bubble)
	var result := world.step()
	return _find_event(result["events"], SimEvent.EventType.BUBBLE_EXPLODED)


func _build_world_with_bubble_loadout(bubble_type: int, power: int, footprint_cells: int) -> SimWorld:
	var config := SimConfig.new()
	config.system_flags["player_slots"] = [
		{"peer_id": 1, "slot_index": 0, "team_id": 1},
		{"peer_id": 2, "slot_index": 1, "team_id": 2},
	]
	config.system_flags["player_bubble_loadouts"] = [
		{"peer_id": 1, "type": bubble_type, "power": power, "footprint_cells": footprint_cells},
		{"peer_id": 2, "type": 1, "power": 1, "footprint_cells": 1},
	]
	var world := SimWorld.new()
	world.bootstrap(config, {"grid": _build_open_map()})
	return world


func _build_open_map() -> GridState:
	return BuiltinMapFactory._build_from_rows([
		"##########",
		"#S......S#",
		"#........#",
		"#........#",
		"#........#",
		"#........#",
		"#........#",
		"#........#",
		"#S......S#",
		"##########",
	])


func _move_player_to(world: SimWorld, player_index: int, cell_x: int, cell_y: int) -> PlayerState:
	var player_id := int(world.state.players.active_ids[player_index])
	var player := world.state.players.get_player(player_id)
	player.cell_x = cell_x
	player.cell_y = cell_y
	player.offset_x = 0
	player.offset_y = 0
	world.state.players.update_player(player)
	world.state.indexes.rebuild_from_state(world.state)
	return player


func _place_bubble(world: SimWorld, slot: int) -> void:
	var frame := InputFrame.new()
	frame.tick = world.state.match_state.tick + 1
	var command := PlayerCommand.neutral()
	command.place_bubble = true
	frame.set_command(slot, command)
	world.enqueue_input(frame)
	world.step()


func _find_event(events: Array, event_type: int) -> SimEvent:
	for event in events:
		if event is SimEvent and event.event_type == event_type:
			return event
	return null


func _sort_cells(raw_cells: Array) -> Array[String]:
	var cells: Array[String] = []
	for raw_cell in raw_cells:
		if raw_cell is Vector2i:
			var cell: Vector2i = raw_cell
			cells.append("%d:%d" % [cell.x, cell.y])
		elif raw_cell is Dictionary:
			var entry: Dictionary = raw_cell
			cells.append("%d:%d" % [int(entry.get("cell_x", 0)), int(entry.get("cell_y", 0))])
	cells.sort()
	return cells
