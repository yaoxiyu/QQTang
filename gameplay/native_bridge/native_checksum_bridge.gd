class_name NativeChecksumBridge
extends RefCounted

const NativeKernelRuntimeScript = preload("res://gameplay/native_bridge/native_kernel_runtime.gd")

# Sentinel：每个 bubble 在 pass_phases 块尾追加，与 native checksum kernel 解码协议对齐。
const BUBBLE_PHASES_SENTINEL := -999999


func build(sim_world: SimWorld, tick_id: int) -> int:
	var native_builder := NativeKernelRuntimeScript.get_checksum_kernel()
	if native_builder == null:
		push_error("[native_checksum_bridge] native checksum kernel is unavailable")
		return 0

	var players := _pack_players(sim_world)
	var bubbles := _pack_bubbles(sim_world)
	var items := _pack_items(sim_world)
	var static_grid := _pack_static_grid(sim_world)
	var mode := _pack_mode(sim_world)
	var match := _pack_match(sim_world)

	var checksum_variant: Variant = native_builder.build_checksum(
		tick_id,
		players,
		bubbles,
		items,
		static_grid,
		mode,
		match,
		sim_world.rng.get_state()
	)

	if checksum_variant is int:
		return int(checksum_variant)

	push_error("[native_checksum_bridge] native checksum returned non-int result")
	return 0


func _pack_match(sim_world: SimWorld) -> PackedInt32Array:
	var match_values := PackedInt32Array()
	match_values.append(sim_world.state.match_state.phase)
	match_values.append(sim_world.state.match_state.winner_team_id)
	match_values.append(sim_world.state.match_state.winner_player_id)
	match_values.append(sim_world.state.match_state.ended_reason)
	match_values.append(sim_world.state.match_state.remaining_ticks)
	return match_values


func _pack_players(sim_world: SimWorld) -> PackedInt32Array:
	var packed := PackedInt32Array()
	for player in _get_sorted_players(sim_world):
		packed.append(player.entity_id)
		packed.append(player.cell_x)
		packed.append(player.cell_y)
		packed.append(player.last_non_zero_move_x)
		packed.append(player.last_non_zero_move_y)
		packed.append(player.offset_x)
		packed.append(player.offset_y)
		packed.append(int(player.last_place_bubble_pressed))
		packed.append(player.move_remainder_units)
		packed.append(player.speed_level)
		packed.append(player.max_speed_level)
		packed.append(int(player.alive))
		packed.append(player.life_state)
		packed.append(player.death_display_ticks)
		packed.append(player.trapped_timeout_ticks)
		packed.append(player.bomb_available)
		packed.append(player.bomb_capacity)
		packed.append(player.max_bomb_capacity)
		packed.append(player.bomb_range)
		packed.append(player.max_bomb_range)
	return packed


func _pack_bubbles(sim_world: SimWorld) -> PackedInt32Array:
	var packed := PackedInt32Array()
	for bubble in _get_sorted_bubbles(sim_world):
		packed.append(bubble.entity_id)
		packed.append(bubble.cell_x)
		packed.append(bubble.cell_y)
		packed.append(bubble.explode_tick)
		packed.append(bubble.bubble_range)
		packed.append(bubble.bubble_type)
		packed.append(bubble.power)
		packed.append(bubble.footprint_cells)
		packed.append(int(bubble.alive))
		# 每条 phase 5 个 int，pass_phases 必须事先按 player_id 升序保存。
		for phase in bubble.pass_phases:
			if phase == null:
				continue
			packed.append(phase.player_id)
			packed.append(phase.phase_x)
			packed.append(phase.sign_x)
			packed.append(phase.phase_y)
			packed.append(phase.sign_y)
		packed.append(BUBBLE_PHASES_SENTINEL)
	return packed


func _pack_items(sim_world: SimWorld) -> PackedInt32Array:
	var packed := PackedInt32Array()
	for item in _get_sorted_items(sim_world):
		packed.append(item.entity_id)
		packed.append(item.cell_x)
		packed.append(item.cell_y)
		packed.append(item.item_type)
		packed.append(int(item.alive))
	return packed


func _pack_static_grid(sim_world: SimWorld) -> PackedInt32Array:
	var packed := PackedInt32Array()
	for y in range(sim_world.state.grid.height):
		for x in range(sim_world.state.grid.width):
			var cell := sim_world.state.grid.get_static_cell(x, y)
			packed.append(x)
			packed.append(y)
			packed.append(cell.tile_type)
			packed.append(cell.tile_flags)
			packed.append(cell.theme_variant)
	return packed


func _pack_mode(sim_world: SimWorld) -> PackedInt32Array:
	var mode := PackedInt32Array()
	mode.append(sim_world.state.mode.mode_timer_ticks)
	mode.append(sim_world.state.mode.payload_owner_id)
	mode.append(sim_world.state.mode.payload_cell_x)
	mode.append(sim_world.state.mode.payload_cell_y)
	mode.append(int(sim_world.state.mode.sudden_death_active))
	return mode


func _get_sorted_players(sim_world: SimWorld) -> Array[PlayerState]:
	var players: Array[PlayerState] = []
	for player_id in range(sim_world.state.players.size()):
		var player := sim_world.state.players.get_player(player_id)
		if player != null:
			players.append(player)
	players.sort_custom(func(a: PlayerState, b: PlayerState): return a.entity_id < b.entity_id)
	return players


func _get_sorted_bubbles(sim_world: SimWorld) -> Array[BubbleState]:
	var bubbles: Array[BubbleState] = []
	for bubble_id in sim_world.state.bubbles.active_ids:
		var bubble := sim_world.state.bubbles.get_bubble(bubble_id)
		if bubble != null:
			bubbles.append(bubble)
	bubbles.sort_custom(func(a: BubbleState, b: BubbleState): return a.entity_id < b.entity_id)
	return bubbles


func _get_sorted_items(sim_world: SimWorld) -> Array[ItemState]:
	var items: Array[ItemState] = []
	for item_id in sim_world.state.items.active_ids:
		var item := sim_world.state.items.get_item(item_id)
		if item != null:
			items.append(item)
	items.sort_custom(func(a: ItemState, b: ItemState): return a.entity_id < b.entity_id)
	return items
