class_name SnapshotService
extends RefCounted

var checksum_builder: ChecksumBuilder = ChecksumBuilder.new()


func build_light_snapshot(sim_world: SimWorld, tick_id: int) -> WorldSnapshot:
	var snapshot := WorldSnapshot.new()
	snapshot.tick_id = tick_id
	snapshot.players = _capture_players(sim_world)
	snapshot.bubbles = _capture_bubbles(sim_world)
	snapshot.items = _capture_items(sim_world)
	snapshot.checksum = checksum_builder.build(sim_world, tick_id)
	return snapshot


func build_standard_snapshot(sim_world: SimWorld, tick_id: int) -> WorldSnapshot:
	var snapshot := build_light_snapshot(sim_world, tick_id)
	snapshot.rng_state = sim_world.rng.get_state()
	snapshot.walls = _capture_walls(sim_world)
	snapshot.mode_state = _capture_mode_state(sim_world)
	snapshot.checksum = checksum_builder.build(sim_world, tick_id)
	return snapshot


func restore_snapshot(sim_world: SimWorld, snapshot: WorldSnapshot) -> void:
	if sim_world == null or snapshot == null:
		return

	sim_world.reset_runtime_only()
	sim_world.rng.set_state(snapshot.rng_state)
	sim_world.state.match_state.tick = snapshot.tick_id
	_restore_players(sim_world, snapshot.players)
	_restore_bubbles(sim_world, snapshot.bubbles)
	_restore_items(sim_world, snapshot.items)
	_restore_walls(sim_world, snapshot.walls)
	_restore_mode_state(sim_world, snapshot.mode_state)
	sim_world.rebuild_runtime_indexes()
	if sim_world.tick_runner != null:
		sim_world.tick_runner.set_tick(snapshot.tick_id)


func build_diff(a: WorldSnapshot, b: WorldSnapshot) -> Dictionary:
	return {
		"tick_a": a.tick_id if a != null else -1,
		"tick_b": b.tick_id if b != null else -1,
		"checksum_a": a.checksum if a != null else 0,
		"checksum_b": b.checksum if b != null else 0,
		"players_equal": a != null and b != null and a.players == b.players,
		"bubbles_equal": a != null and b != null and a.bubbles == b.bubbles,
		"items_equal": a != null and b != null and a.items == b.items,
		"walls_equal": a != null and b != null and a.walls == b.walls,
		"mode_equal": a != null and b != null and a.mode_state == b.mode_state
	}


func _capture_players(sim_world: SimWorld) -> Array[Dictionary]:
	var players: Array[Dictionary] = []
	for player_id in sim_world.state.players.active_ids:
		var player := sim_world.state.players.get_player(player_id)
		if player == null:
			continue
		players.append({
			"entity_id": player.entity_id,
			"generation": player.generation,
			"player_slot": player.player_slot,
			"team_id": player.team_id,
			"alive": player.alive,
			"life_state": player.life_state,
			"cell_x": player.cell_x,
			"cell_y": player.cell_y,
			"offset_x": player.offset_x,
			"offset_y": player.offset_y,
			"facing": player.facing,
			"move_state": player.move_state,
			"last_non_zero_move_x": player.last_non_zero_move_x,
			"last_non_zero_move_y": player.last_non_zero_move_y,
			"speed_level": player.speed_level,
			"bomb_capacity": player.bomb_capacity,
			"bomb_available": player.bomb_available,
			"bomb_range": player.bomb_range,
			"bomb_fuse_ticks": player.bomb_fuse_ticks,
			"has_kick": player.has_kick,
			"has_push": player.has_push,
			"has_remote": player.has_remote,
			"has_pierce": player.has_pierce,
			"can_cross_own_bubble": player.can_cross_own_bubble,
			"shield_ticks": player.shield_ticks,
			"invincible_ticks": player.invincible_ticks,
			"stun_ticks": player.stun_ticks,
			"respawn_ticks": player.respawn_ticks,
			"trap_bubble_id": player.trap_bubble_id,
			"last_damage_from_player_id": player.last_damage_from_player_id,
			"kills": player.kills,
			"deaths": player.deaths,
			"score": player.score,
			"controller_type": player.controller_type
		})
	players.sort_custom(func(a: Dictionary, b: Dictionary): return int(a["entity_id"]) < int(b["entity_id"]))
	return players


func _capture_bubbles(sim_world: SimWorld) -> Array[Dictionary]:
	var bubbles: Array[Dictionary] = []
	for bubble_id in sim_world.state.bubbles.active_ids:
		var bubble := sim_world.state.bubbles.get_bubble(bubble_id)
		if bubble == null:
			continue
		bubbles.append({
			"entity_id": bubble.entity_id,
			"generation": bubble.generation,
			"alive": bubble.alive,
			"owner_player_id": bubble.owner_player_id,
			"bubble_type": bubble.bubble_type,
			"cell_x": bubble.cell_x,
			"cell_y": bubble.cell_y,
			"spawn_tick": bubble.spawn_tick,
			"explode_tick": bubble.explode_tick,
			"bubble_range": bubble.bubble_range,
			"moving_state": bubble.moving_state,
			"move_dir_x": bubble.move_dir_x,
			"move_dir_y": bubble.move_dir_y,
			"pierce": bubble.pierce,
			"chain_triggered": bubble.chain_triggered,
			"remote_group_id": bubble.remote_group_id
		})
	bubbles.sort_custom(func(a: Dictionary, b: Dictionary): return int(a["entity_id"]) < int(b["entity_id"]))
	return bubbles


func _capture_items(sim_world: SimWorld) -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	for item_id in sim_world.state.items.active_ids:
		var item := sim_world.state.items.get_item(item_id)
		if item == null:
			continue
		items.append({
			"entity_id": item.entity_id,
			"generation": item.generation,
			"alive": item.alive,
			"item_type": item.item_type,
			"cell_x": item.cell_x,
			"cell_y": item.cell_y,
			"spawn_tick": item.spawn_tick,
			"pickup_delay_ticks": item.pickup_delay_ticks,
			"visible": item.visible
		})
	items.sort_custom(func(a: Dictionary, b: Dictionary): return int(a["entity_id"]) < int(b["entity_id"]))
	return items


func _capture_walls(sim_world: SimWorld) -> Array[Dictionary]:
	var walls: Array[Dictionary] = []
	for y in range(sim_world.state.grid.height):
		for x in range(sim_world.state.grid.width):
			var cell = sim_world.state.grid.get_static_cell(x, y)
			walls.append({
				"cell_x": x,
				"cell_y": y,
				"tile_type": cell.tile_type,
				"tile_flags": cell.tile_flags,
				"theme_variant": cell.theme_variant
			})
	return walls


func _capture_mode_state(sim_world: SimWorld) -> Dictionary:
	return {
		"mode_runtime_type": String(sim_world.state.mode.mode_runtime_type),
		"team_alive_counts": sim_world.state.mode.team_alive_counts.duplicate(true),
		"mode_timer_ticks": sim_world.state.mode.mode_timer_ticks,
		"payload_owner_id": sim_world.state.mode.payload_owner_id,
		"payload_cell_x": sim_world.state.mode.payload_cell_x,
		"payload_cell_y": sim_world.state.mode.payload_cell_y,
		"sudden_death_active": sim_world.state.mode.sudden_death_active,
		"custom_ints": sim_world.state.mode.custom_ints.duplicate(true),
		"custom_flags": sim_world.state.mode.custom_flags.duplicate(true)
	}


func _restore_players(sim_world: SimWorld, players: Array[Dictionary]) -> void:
	sim_world.state.players.clear()
	for data in players:
		var player_id := sim_world.state.players.add_player(
			int(data.get("player_slot", 0)),
			int(data.get("team_id", 0)),
			int(data.get("cell_x", 0)),
			int(data.get("cell_y", 0))
		)
		var player := sim_world.state.players.get_player(player_id)
		player.entity_id = int(data.get("entity_id", player.entity_id))
		player.generation = int(data.get("generation", player.generation))
		player.alive = bool(data.get("alive", true))
		player.life_state = int(data.get("life_state", player.life_state))
		player.offset_x = int(data.get("offset_x", 0))
		player.offset_y = int(data.get("offset_y", 0))
		player.facing = int(data.get("facing", player.facing))
		player.move_state = int(data.get("move_state", player.move_state))
		player.last_non_zero_move_x = int(data.get("last_non_zero_move_x", 0))
		player.last_non_zero_move_y = int(data.get("last_non_zero_move_y", 0))
		player.speed_level = int(data.get("speed_level", player.speed_level))
		player.bomb_capacity = int(data.get("bomb_capacity", player.bomb_capacity))
		player.bomb_available = int(data.get("bomb_available", player.bomb_available))
		player.bomb_range = int(data.get("bomb_range", player.bomb_range))
		player.bomb_fuse_ticks = int(data.get("bomb_fuse_ticks", player.bomb_fuse_ticks))
		player.has_kick = bool(data.get("has_kick", false))
		player.has_push = bool(data.get("has_push", false))
		player.has_remote = bool(data.get("has_remote", false))
		player.has_pierce = bool(data.get("has_pierce", false))
		player.can_cross_own_bubble = bool(data.get("can_cross_own_bubble", false))
		player.shield_ticks = int(data.get("shield_ticks", 0))
		player.invincible_ticks = int(data.get("invincible_ticks", 0))
		player.stun_ticks = int(data.get("stun_ticks", 0))
		player.respawn_ticks = int(data.get("respawn_ticks", 0))
		player.trap_bubble_id = int(data.get("trap_bubble_id", -1))
		player.last_damage_from_player_id = int(data.get("last_damage_from_player_id", -1))
		player.kills = int(data.get("kills", 0))
		player.deaths = int(data.get("deaths", 0))
		player.score = int(data.get("score", 0))
		player.controller_type = int(data.get("controller_type", player.controller_type))
		sim_world.state.players.update_player(player)


func _restore_bubbles(sim_world: SimWorld, bubbles: Array[Dictionary]) -> void:
	sim_world.state.bubbles.clear()
	for data in bubbles:
		var bubble_id := sim_world.state.bubbles.spawn_bubble(
			int(data.get("owner_player_id", -1)),
			int(data.get("cell_x", 0)),
			int(data.get("cell_y", 0)),
			int(data.get("bubble_range", 1)),
			int(data.get("explode_tick", 0))
		)
		var bubble := sim_world.state.bubbles.get_bubble(bubble_id)
		bubble.entity_id = int(data.get("entity_id", bubble.entity_id))
		bubble.generation = int(data.get("generation", bubble.generation))
		bubble.alive = bool(data.get("alive", true))
		bubble.bubble_type = int(data.get("bubble_type", bubble.bubble_type))
		bubble.spawn_tick = int(data.get("spawn_tick", bubble.spawn_tick))
		bubble.moving_state = int(data.get("moving_state", bubble.moving_state))
		bubble.move_dir_x = int(data.get("move_dir_x", 0))
		bubble.move_dir_y = int(data.get("move_dir_y", 0))
		bubble.pierce = bool(data.get("pierce", false))
		bubble.chain_triggered = bool(data.get("chain_triggered", false))
		bubble.remote_group_id = int(data.get("remote_group_id", 0))
		sim_world.state.bubbles.update_bubble(bubble)


func _restore_items(sim_world: SimWorld, items: Array[Dictionary]) -> void:
	sim_world.state.items.clear()
	for data in items:
		var item_id := sim_world.state.items.spawn_item(
			int(data.get("item_type", 0)),
			int(data.get("cell_x", 0)),
			int(data.get("cell_y", 0)),
			int(data.get("pickup_delay_ticks", 0))
		)
		var item := sim_world.state.items.get_item(item_id)
		item.entity_id = int(data.get("entity_id", item.entity_id))
		item.generation = int(data.get("generation", item.generation))
		item.alive = bool(data.get("alive", true))
		item.spawn_tick = int(data.get("spawn_tick", item.spawn_tick))
		item.visible = bool(data.get("visible", true))
		sim_world.state.items.update_item(item)


func _restore_walls(sim_world: SimWorld, walls: Array[Dictionary]) -> void:
	for wall in walls:
		var cell := sim_world.state.grid.get_static_cell(int(wall.get("cell_x", 0)), int(wall.get("cell_y", 0)))
		cell.tile_type = int(wall.get("tile_type", cell.tile_type))
		cell.tile_flags = int(wall.get("tile_flags", cell.tile_flags))
		cell.theme_variant = int(wall.get("theme_variant", cell.theme_variant))
		sim_world.state.grid.set_static_cell(int(wall.get("cell_x", 0)), int(wall.get("cell_y", 0)), cell)


func _restore_mode_state(sim_world: SimWorld, mode_state: Dictionary) -> void:
	sim_world.state.mode.mode_runtime_type = StringName(mode_state.get("mode_runtime_type", "default"))
	sim_world.state.mode.team_alive_counts = mode_state.get("team_alive_counts", {}).duplicate(true)
	sim_world.state.mode.mode_timer_ticks = int(mode_state.get("mode_timer_ticks", 0))
	sim_world.state.mode.payload_owner_id = int(mode_state.get("payload_owner_id", -1))
	sim_world.state.mode.payload_cell_x = int(mode_state.get("payload_cell_x", -1))
	sim_world.state.mode.payload_cell_y = int(mode_state.get("payload_cell_y", -1))
	sim_world.state.mode.sudden_death_active = bool(mode_state.get("sudden_death_active", false))
	sim_world.state.mode.custom_ints = mode_state.get("custom_ints", {}).duplicate(true)
	sim_world.state.mode.custom_flags = mode_state.get("custom_flags", {}).duplicate(true)
