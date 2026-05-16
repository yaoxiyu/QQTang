# 角色：
# 状态效果系统，处理方块摧毁/爆炸泡泡返还
#
# 读写边界：
# - 读：exploded_bubbles, cells_to_destroy
# - 写：GridState, bomb_available
#
# 禁止事项：
# - 不在这里做规则判断
# - 玩家死亡由 PlayerLifeTransitionSystem 统一处理

class_name StatusEffectSystem
extends ISimSystem

const PlayerLocator = preload("res://gameplay/simulation/movement/player_locator.gd")
const LogSimulationScript = preload("res://app/logging/log_simulation.gd")

# ====================
# 系统接口
# ====================

func get_name() -> StringName:
	return "StatusEffectSystem"

func execute(ctx: SimContext) -> void:
	_process_destroyed_cells(ctx)

	# 处理爆炸泡泡返还
	for bubble_id in ctx.scratch.exploded_bubble_ids:
		var bubble = ctx.state.bubbles.get_bubble(bubble_id)
		if bubble == null:
			continue

		var owner_id = bubble.owner_player_id
		var player = ctx.state.players.get_player(owner_id)
		if player == null or not player.alive:
			continue

		# 返还泡泡容量（直到达到最大容量）
		if player.bomb_available < player.bomb_capacity:
			player.bomb_available += 1
			ctx.state.players.update_player(player)


func _process_destroyed_cells(ctx: SimContext) -> void:
	if _should_suppress_breakable_destroy_prediction(ctx):
		return
	for cell in ctx.scratch.cells_to_destroy:
		if not ctx.state.grid.is_in_bounds(cell.x, cell.y):
			continue

		var static_cell := ctx.state.grid.get_static_cell(cell.x, cell.y)
		if static_cell.tile_type != TileConstants.TileType.BREAKABLE_BLOCK:
			continue

		var can_spawn_item: bool = (static_cell.tile_flags & TileConstants.TILE_CAN_SPAWN_ITEM) != 0
		ctx.state.grid.set_static_cell(cell.x, cell.y, TileFactory.make_empty())

		var destroyed_event := SimEvent.new(ctx.tick, SimEvent.EventType.CELL_DESTROYED)
		destroyed_event.payload = {
			"cell_x": cell.x,
			"cell_y": cell.y,
			"can_spawn_item": can_spawn_item,
		}
		ctx.events.push(destroyed_event)

		LogSimulationScript.info(
			"stage=cell_destroyed tick=%d cell=(%d,%d) can_spawn_item=%s" % [ctx.tick, cell.x, cell.y, str(can_spawn_item)],
			"", 0, "sync.trace simulation.explosion_item"
		)


func _should_suppress_breakable_destroy_prediction(ctx: SimContext) -> bool:
	if ctx == null or ctx.state == null or ctx.state.runtime_flags == null:
		return false
	return bool(ctx.state.runtime_flags.client_prediction_mode)
