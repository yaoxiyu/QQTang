# 角色：
# 移动系统，处理玩家移动逻辑。
# **只走 native kernel** —— GD 端只负责把 SimContext 喂给 native，并把回写应用到 SimState。
# native 不可用时本帧不动玩家（push_error 提示，但不崩溃）。
#
# 读写边界：
# - 读：玩家命令、SimQueries（仅在测试 / 表现层使用）
# - 写：PlayerState 位置、SimIndexes.players_by_cell、BubbleState.pass_phases
#
# 禁止事项：
# - 不在这里写运动规则；规则在 native_movement_kernel.cpp 内
# - 不直接读取 Node2D.position
# - 不在这里放泡泡

class_name MovementSystem
extends ISimSystem

const BubblePassPhaseScript = preload("res://gameplay/simulation/entities/bubble_pass_phase.gd")
const BubblePassPhaseHelper = preload("res://gameplay/simulation/movement/bubble_pass_phase_helper.gd")
const LogSimulationScript = preload("res://app/logging/log_simulation.gd")
const NativeKernelRuntimeScript = preload("res://gameplay/native_bridge/native_kernel_runtime.gd")
const NativeMovementBridgeScript = preload("res://gameplay/native_bridge/native_movement_bridge.gd")

const DEBUG_REMOTE_ANIM_LOG := false

var _native_movement_bridge: NativeMovementBridge = NativeMovementBridgeScript.new()


func get_name() -> StringName:
	return "MovementSystem"


func execute(ctx: SimContext) -> void:
	if not NativeKernelRuntimeScript.is_available() or not NativeKernelRuntimeScript.has_movement_kernel():
		push_error("[movement_system] native movement kernel unavailable; skipping movement this tick")
		return
	_execute_native_path(ctx)


func _execute_native_path(ctx: SimContext) -> bool:
	var candidate_player_ids: Array[int] = []
	for player_id in ctx.state.players.active_ids:
		var player = ctx.state.players.get_player(player_id)
		if player == null or not player.alive:
			continue
		if player.life_state != PlayerState.LifeState.NORMAL:
			player.move_state = PlayerState.MoveState.IDLE
			player.move_remainder_units = 0
			ctx.state.players.update_player(player)
			continue
		if _should_preserve_authoritative_remote_state(ctx, player):
			continue
		candidate_player_ids.append(player_id)

	var result := _native_movement_bridge.step_players(ctx, candidate_player_ids)
	if candidate_player_ids.size() > 0 and result.get("player_updates", []).size() != candidate_player_ids.size():
		push_error("[movement_system] native movement returned incomplete player_updates")
		return false

	_apply_native_player_updates(ctx, result.get("player_updates", []))
	_apply_native_bubble_phase_updates(ctx, result.get("bubble_phase_updates", []))
	_apply_native_cell_changes(ctx, result.get("cell_changes", []))
	_apply_native_blocked_events(ctx, result.get("blocked_events", []))
	return true


func _apply_native_player_updates(ctx: SimContext, player_updates: Array) -> void:
	for raw_update in player_updates:
		if not (raw_update is Dictionary):
			continue
		var update: Dictionary = raw_update
		var player_id := int(update.get("player_id", -1))
		if player_id < 0:
			continue
		var player := ctx.state.players.get_player(player_id)
		if player == null:
			continue
		player.cell_x = int(update.get("cell_x", player.cell_x))
		player.cell_y = int(update.get("cell_y", player.cell_y))
		player.offset_x = int(update.get("offset_x", player.offset_x))
		player.offset_y = int(update.get("offset_y", player.offset_y))
		player.facing = int(update.get("facing", player.facing))
		player.move_state = int(update.get("move_state", player.move_state))
		player.move_remainder_units = int(update.get("move_remainder_units", player.move_remainder_units))
		player.last_non_zero_move_x = int(update.get("last_non_zero_move_x", player.last_non_zero_move_x))
		player.last_non_zero_move_y = int(update.get("last_non_zero_move_y", player.last_non_zero_move_y))
		ctx.state.players.update_player(player)


func _apply_native_bubble_phase_updates(ctx: SimContext, updates: Array) -> void:
	# Native kernel 推进 phase 的回写。
	# 每条 update：{ bubble_id, player_id, phase_x, sign_x, phase_y, sign_y, removed }
	# removed=true 表示玩家已与该泡泡完全无重叠且 phase 已达 (C,C)，可移除条目。
	for raw_update in updates:
		if not (raw_update is Dictionary):
			continue
		var update: Dictionary = raw_update
		var bubble_id := int(update.get("bubble_id", -1))
		var player_id := int(update.get("player_id", -1))
		if bubble_id < 0 or player_id < 0:
			continue
		var bubble := ctx.state.bubbles.get_bubble(bubble_id)
		if bubble == null:
			continue
		if bool(update.get("removed", false)):
			if BubblePassPhaseHelper.remove_phase(bubble, player_id):
				ctx.state.bubbles.update_bubble(bubble)
			continue
		var phase := BubblePassPhaseScript.new()
		phase.player_id = player_id
		phase.phase_x = int(update.get("phase_x", BubblePassPhaseScript.Phase.A))
		phase.sign_x = int(update.get("sign_x", 0))
		phase.phase_y = int(update.get("phase_y", BubblePassPhaseScript.Phase.A))
		phase.sign_y = int(update.get("sign_y", 0))
		BubblePassPhaseHelper.upsert_phase(bubble, phase)
		ctx.state.bubbles.update_bubble(bubble)


func _apply_native_cell_changes(ctx: SimContext, cell_changes: Array) -> void:
	for raw_change in cell_changes:
		if not (raw_change is Dictionary):
			continue
		var change: Dictionary = raw_change
		_emit_cell_changed_if_needed(
			ctx,
			int(change.get("player_id", -1)),
			int(change.get("from_cell_x", 0)),
			int(change.get("from_cell_y", 0)),
			int(change.get("to_cell_x", 0)),
			int(change.get("to_cell_y", 0))
		)


func _apply_native_blocked_events(ctx: SimContext, blocked_events: Array) -> void:
	for raw_event in blocked_events:
		if not (raw_event is Dictionary):
			continue
		var blocked_event: Dictionary = raw_event
		_emit_blocked_event(
			ctx,
			int(blocked_event.get("player_id", -1)),
			int(blocked_event.get("from_cell_x", 0)),
			int(blocked_event.get("from_cell_y", 0)),
			int(blocked_event.get("blocked_cell_x", 0)),
			int(blocked_event.get("blocked_cell_y", 0))
		)


# 客户端预测时跳过非本机控制玩家：让权威快照覆盖他们的位置/动画，避免本端预测污染。
# 同样的判断在 InputSystem 也有一份独立实现——两者职责不同（input vs movement），各自维护。
func _should_preserve_authoritative_remote_state(ctx: SimContext, player: PlayerState) -> bool:
	if ctx == null or ctx.state == null or player == null:
		return false
	var runtime_flags := ctx.state.runtime_flags
	if runtime_flags == null or not runtime_flags.client_prediction_mode:
		return false
	var preserve : bool = player.player_slot != runtime_flags.client_controlled_player_slot
	if preserve and DEBUG_REMOTE_ANIM_LOG:
		LogSimulationScript.debug(
			"slot=%d controlled_slot=%d move_state=%d facing=%d last=(%d,%d)" % [
				player.player_slot,
				runtime_flags.client_controlled_player_slot,
				player.move_state,
				player.facing,
				player.last_non_zero_move_x,
				player.last_non_zero_move_y,
			],
			"",
			0,
			"simulation.movement.remote_anim"
		)
	return preserve


func _emit_cell_changed_if_needed(
	ctx: SimContext,
	player_id: int,
	from_x: int,
	from_y: int,
	to_x: int,
	to_y: int
) -> void:
	if from_x == to_x and from_y == to_y:
		return

	_update_player_cell_index(ctx, player_id, from_x, from_y, to_x, to_y)

	var moved_event := SimEvent.new(ctx.tick, SimEvent.EventType.PLAYER_MOVED)
	moved_event.payload = {
		"player_id": player_id,
		"from_cell_x": from_x,
		"from_cell_y": from_y,
		"to_cell_x": to_x,
		"to_cell_y": to_y
	}
	ctx.events.push(moved_event)


func _emit_blocked_event(
	ctx: SimContext,
	player_id: int,
	from_x: int,
	from_y: int,
	to_x: int,
	to_y: int
) -> void:
	var blocked_event := SimEvent.new(ctx.tick, SimEvent.EventType.PLAYER_BLOCKED)
	blocked_event.payload = {
		"player_id": player_id,
		"from_cell_x": from_x,
		"from_cell_y": from_y,
		"to_cell_x": to_x,
		"to_cell_y": to_y
	}
	ctx.events.push(blocked_event)


func _update_player_cell_index(
	ctx: SimContext,
	player_id: int,
	from_x: int,
	from_y: int,
	to_x: int,
	to_y: int
) -> void:
	if from_x == to_x and from_y == to_y:
		return

	if ctx.state.grid.is_in_bounds(from_x, from_y):
		var from_idx := ctx.state.grid.to_cell_index(from_x, from_y)
		if from_idx >= 0 and from_idx < ctx.state.indexes.players_by_cell.size():
			var from_list: Array = ctx.state.indexes.players_by_cell[from_idx]
			var pos := from_list.find(player_id)
			if pos != -1:
				from_list.remove_at(pos)

	if ctx.state.grid.is_in_bounds(to_x, to_y):
		var to_idx := ctx.state.grid.to_cell_index(to_x, to_y)
		if to_idx >= 0 and to_idx < ctx.state.indexes.players_by_cell.size():
			var to_list: Array = ctx.state.indexes.players_by_cell[to_idx]
			if not to_list.has(player_id):
				to_list.append(player_id)
