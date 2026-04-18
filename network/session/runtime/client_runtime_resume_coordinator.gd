extends RefCounted

const BubblePlaceResolverScript = preload("res://gameplay/simulation/movement/bubble_place_resolver.gd")
const LogSyncScript = preload("res://app/logging/log_sync.gd")

const TRACE_TAG := "sync.trace"
const PLACE_CONFIRM_TIMEOUT_TICKS := 12

var last_applied_authority_sideband_tick: int = -1
var _pending_place_request_tick: int = -1
var _pending_place_baseline_bubble_count: int = -1
var _pending_place_baseline_bomb_available: int = -1
var _pending_place_timeout_logged: bool = false


func reset() -> void:
	last_applied_authority_sideband_tick = -1
	clear_pending_place_request()


func should_apply_authority_sideband(predicted_world: SimWorld, suppress_authority_only_entities: bool, message_tick: int) -> bool:
	if predicted_world == null:
		return false
	if not suppress_authority_only_entities:
		return true
	return message_tick > last_applied_authority_sideband_tick


func note_applied_authority_sideband(applied_tick: int) -> void:
	if applied_tick >= 0:
		last_applied_authority_sideband_tick = max(last_applied_authority_sideband_tick, applied_tick)


func track_local_place_request(world: SimWorld, tick_id: int) -> void:
	_pending_place_request_tick = tick_id
	_pending_place_timeout_logged = false
	_pending_place_baseline_bubble_count = world.state.bubbles.active_ids.size() if world != null else -1
	_pending_place_baseline_bomb_available = get_controlled_player_bomb_available(world)


func resolve_local_place_action(requested_place: bool, local_tick: int, world: SimWorld) -> bool:
	if not requested_place:
		return false
	if world == null:
		LogSyncScript.warn("place_request tick=%d effective=true reason=no_prediction_world" % local_tick, "", 0, "%s sync.client_runtime" % TRACE_TAG)
		return true
	var player := get_controlled_player_state(world)
	if player == null:
		LogSyncScript.warn("place_request tick=%d effective=true reason=no_controlled_player" % local_tick, "", 0, "%s sync.client_runtime" % TRACE_TAG)
		return true
	var target_cell := BubblePlaceResolverScript.resolve_place_cell(player)
	var bomb_available := int(player.bomb_available)
	if bomb_available <= 0:
		LogSyncScript.warn(
			"place_blocked reason=no_bomb tick=%d slot=%d entity=%d bomb_available=%d cell=(%d,%d)" % [
				local_tick, int(player.player_slot), int(player.entity_id), bomb_available, target_cell.x, target_cell.y,
			],
			"",
			0,
			"%s sync.client_runtime" % TRACE_TAG
		)
		return false
	if world.state.grid == null or not world.state.grid.is_in_bounds(target_cell.x, target_cell.y):
		LogSyncScript.warn(
			"place_blocked reason=out_of_bounds tick=%d slot=%d entity=%d cell=(%d,%d)" % [
				local_tick, int(player.player_slot), int(player.entity_id), target_cell.x, target_cell.y,
			],
			"",
			0,
			"%s sync.client_runtime" % TRACE_TAG
		)
		return false
	var bubble_at_cell := world.queries.get_bubble_at(target_cell.x, target_cell.y)
	if bubble_at_cell != -1:
		LogSyncScript.warn(
			"place_blocked reason=bubble_occupied tick=%d slot=%d entity=%d bubble_id=%d cell=(%d,%d)" % [
				local_tick, int(player.player_slot), int(player.entity_id), bubble_at_cell, target_cell.x, target_cell.y,
			],
			"",
			0,
			"%s sync.client_runtime" % TRACE_TAG
		)
		return false
	LogSyncScript.debug(
		"place_request tick=%d effective=true slot=%d entity=%d bomb_available=%d cell=(%d,%d)" % [
			local_tick, int(player.player_slot), int(player.entity_id), bomb_available, target_cell.x, target_cell.y,
		],
		"",
		0,
		"%s sync.client_runtime" % TRACE_TAG
	)
	return true


func inspect_pending_place_request(authoritative_tick: int, source: String, world: SimWorld) -> void:
	if _pending_place_request_tick < 0:
		return
	var bubble_count := world.state.bubbles.active_ids.size() if world != null else -1
	var bomb_available := get_controlled_player_bomb_available(world)
	var confirmed := false
	if _pending_place_baseline_bubble_count >= 0 and bubble_count > _pending_place_baseline_bubble_count:
		confirmed = true
	if not confirmed and _pending_place_baseline_bomb_available >= 0 and bomb_available >= 0 and bomb_available < _pending_place_baseline_bomb_available:
		confirmed = true
	if confirmed:
		clear_pending_place_request()
		return
	if authoritative_tick - _pending_place_request_tick < PLACE_CONFIRM_TIMEOUT_TICKS:
		return
	if _pending_place_timeout_logged:
		return
	_pending_place_timeout_logged = true
	LogSyncScript.warn(
		"anomaly=place_unconfirmed source=%s send_tick=%d auth_tick=%d baseline_bubbles=%d current_bubbles=%d baseline_bomb=%d current_bomb=%d" % [
			source,
			_pending_place_request_tick,
			authoritative_tick,
			_pending_place_baseline_bubble_count,
			bubble_count,
			_pending_place_baseline_bomb_available,
			bomb_available,
		],
		"",
		0,
		"%s sync.client_runtime" % TRACE_TAG
	)


func clear_pending_place_request() -> void:
	_pending_place_request_tick = -1
	_pending_place_baseline_bubble_count = -1
	_pending_place_baseline_bomb_available = -1
	_pending_place_timeout_logged = false


func get_controlled_player_bomb_available(world: SimWorld) -> int:
	if world == null:
		return -1
	var player := get_controlled_player_state(world)
	if player == null:
		return -1
	return int(player.bomb_available)


func get_controlled_player_state(world: SimWorld) -> PlayerState:
	if world == null:
		return null
	var controlled_slot := int(world.state.runtime_flags.client_controlled_player_slot)
	for player_id in world.state.players.active_ids:
		var player := world.state.players.get_player(player_id)
		if player == null:
			continue
		if player.player_slot == controlled_slot:
			return player
	return null
