class_name Phase2SandboxBootstrap
extends Node

const ServerSessionScript = preload("res://gameplay/network/session/server_session.gd")
const ClientSessionScript = preload("res://gameplay/network/session/client_session.gd")
const MessagePipeScript = preload("res://gameplay/sandbox/phase2/local_message_pipe.gd")
const PredictedClientScript = preload("res://gameplay/sandbox/phase2/predicted_client.gd")
const MatchResultBannerScript = preload("res://presentation/sandbox/phase2/match_result_banner.gd")
const MapFactoryScript = preload("res://gameplay/sandbox/phase2/sandbox_map_factory.gd")
const ItemDropBridgeScript = preload("res://gameplay/sandbox/phase2/item_drop_bridge.gd")

@export var presentation_root_path: NodePath = ^"../PresentationRoot"
@export var simple_hud_path: NodePath = ^"../CanvasLayer/SimpleDebugHud"
@export var net_debug_overlay_path: NodePath = ^"../CanvasLayer/NetDebugOverlay"

@export var tick_rate: int = 20
@export var input_delay_ticks: int = 3
@export var seed: int = 20260326

var server: ServerSession = null
var client_a: ClientSession = null
var client_b: ClientSession = null
var pipe: Phase2LocalMessagePipe = null
var predictor_a: Phase2PredictedClient = null
var predictor_b: Phase2PredictedClient = null
var result_banner: Phase2MatchResultBanner = null
var item_drop_bridge: Phase2ItemDropBridge = null

var presentation_root: Phase2PresentationBridge = null
var simple_hud: Phase2SimpleDebugHud = null
var net_debug_overlay: Phase2NetDebugOverlay = null

var _tick_interval_seconds: float = 0.05
var _tick_interval_ms: float = 50.0
var _accumulator: float = 0.0
var _paused: bool = false
var _single_step_requested: bool = false

var _last_place_pressed_a: bool = false
var _last_place_pressed_b: bool = false
var _last_debug_pressed: Dictionary = {}

var _latency_profiles: Array[int] = [0, 80, 150]
var _loss_profiles: Array[float] = [0.0, 0.05, 0.10]
var _latency_profile_index: int = 0
var _loss_profile_index: int = 0

var _last_metrics: Dictionary = {}


func _ready() -> void:
	_tick_interval_seconds = 1.0 / float(max(tick_rate, 1))
	_tick_interval_ms = _tick_interval_seconds * 1000.0
	_resolve_scene_refs()
	_ensure_result_banner()
	_setup_runtime()
	call_deferred("_deferred_start_match")


func _deferred_start_match() -> void:
	_start_match()


func _process(delta: float) -> void:
	if server == null or server.active_match == null:
		return

	_handle_debug_shortcuts()

	if _paused and not _single_step_requested:
		_refresh_views()
		return

	_accumulator += delta
	while _accumulator >= _tick_interval_seconds:
		_accumulator -= _tick_interval_seconds
		_run_one_tick()
		if _single_step_requested:
			_single_step_requested = false
			_paused = true
			break

	_refresh_views()


func restart_match() -> void:
	_cleanup_match()
	_start_match()


func toggle_pause() -> void:
	_paused = not _paused


func request_single_step() -> void:
	_single_step_requested = true
	_paused = false


func cycle_latency_profile() -> void:
	_latency_profile_index = (_latency_profile_index + 1) % _latency_profiles.size()
	_apply_network_profile()


func cycle_loss_profile() -> void:
	_loss_profile_index = (_loss_profile_index + 1) % _loss_profiles.size()
	_apply_network_profile()


func _resolve_scene_refs() -> void:
	if has_node(presentation_root_path):
		presentation_root = get_node(presentation_root_path)
	if has_node(simple_hud_path):
		simple_hud = get_node(simple_hud_path)
	if has_node(net_debug_overlay_path):
		net_debug_overlay = get_node(net_debug_overlay_path)


func _ensure_result_banner() -> void:
	if simple_hud == null:
		return
	var canvas_layer := simple_hud.get_parent()
	if canvas_layer == null:
		return

	if canvas_layer.has_node("MatchResultBanner"):
		result_banner = canvas_layer.get_node("MatchResultBanner")
		return

	result_banner = MatchResultBannerScript.new()
	result_banner.name = "MatchResultBanner"
	result_banner.position = Vector2(360, 120)
	result_banner.size = Vector2(560, 80)
	canvas_layer.add_child(result_banner)


func _setup_runtime() -> void:
	pipe = MessagePipeScript.new()
	server = ServerSessionScript.new()
	client_a = ClientSessionScript.new()
	client_b = ClientSessionScript.new()
	predictor_a = PredictedClientScript.new()
	predictor_b = PredictedClientScript.new()
	item_drop_bridge = ItemDropBridgeScript.new()

	add_child(server)
	add_child(client_a)
	add_child(client_b)

	client_a.configure(101)
	client_b.configure(202)
	predictor_a.configure(client_a.local_peer_id, 0)
	predictor_b.configure(client_b.local_peer_id, 1)
	_apply_network_profile()


func _start_match() -> void:
	_accumulator = 0.0
	_paused = false
	_single_step_requested = false
	_last_place_pressed_a = false
	_last_place_pressed_b = false
	_last_metrics.clear()

	client_a.configure(client_a.local_peer_id if client_a.local_peer_id != 0 else 101)
	client_b.configure(client_b.local_peer_id if client_b.local_peer_id != 0 else 202)
	predictor_a.configure(client_a.local_peer_id, 0)
	predictor_b.configure(client_b.local_peer_id, 1)
	if item_drop_bridge != null:
		item_drop_bridge.reset()
	if result_banner != null:
		result_banner.apply_result("", false)

	server.create_room("phase2_sandbox_room", "large_map", "default")
	server.add_peer(client_a.local_peer_id)
	server.add_peer(client_b.local_peer_id)
	server.set_peer_ready(client_a.local_peer_id, true)
	server.set_peer_ready(client_b.local_peer_id, true)

	var config := SimConfig.new()
	var started := server.start_match(config, {
		"grid": MapFactoryScript.build_large_map()
	}, seed, 0)
	if not started:
		push_error("Phase2 sandbox failed to start match.")
		return

	if presentation_root != null and server.active_match != null:
		presentation_root.configure_from_world(server.active_match.sim_world)

	_refresh_views()


func _cleanup_match() -> void:
	if pipe != null:
		pipe.reset()

	if predictor_a != null:
		predictor_a.reset()
	if predictor_b != null:
		predictor_b.reset()
	if item_drop_bridge != null:
		item_drop_bridge.reset()
	if result_banner != null:
		result_banner.apply_result("", false)

	if server != null and server.active_match != null:
		server.active_match.dispose()
		server.active_match = null


func _apply_network_profile() -> void:
	if pipe == null:
		return

	pipe.configure(
		_latency_profiles[_latency_profile_index],
		_loss_profiles[_loss_profile_index]
	)


func _run_one_tick() -> void:
	if server == null or server.active_match == null:
		return

	var next_tick := server.active_match.sim_world.state.match_state.tick + 1
	_enqueue_local_inputs(next_tick + input_delay_ticks)
	pipe.advance(_tick_interval_ms)

	for frame in pipe.flush_server_inputs():
		server.receive_input(frame)

	server.tick_once()
	if item_drop_bridge != null:
		item_drop_bridge.process_tick(server.active_match.sim_world)
	_queue_server_messages(server.poll_messages())
	_flush_client_message_queue()


func _enqueue_local_inputs(target_tick: int) -> void:
	var blocking_summary := server.active_match.build_player_position_summary()
	var grid := server.active_match.sim_world.state.grid

	var frame_a := _sample_player_input(
		client_a,
		target_tick,
		KEY_W,
		KEY_S,
		KEY_A,
		KEY_D,
		KEY_SPACE,
		_last_place_pressed_a
	)
	_last_place_pressed_a = bool(frame_a.get("place_pressed", false))
	var input_a: PlayerInputFrame = frame_a.get("frame")
	_queue_client_frame(client_a, input_a)
	predictor_a.record_local_input(input_a, blocking_summary, grid)

	var frame_b := _sample_player_input(
		client_b,
		target_tick,
		KEY_UP,
		KEY_DOWN,
		KEY_LEFT,
		KEY_RIGHT,
		KEY_ENTER,
		_last_place_pressed_b
	)
	_last_place_pressed_b = bool(frame_b.get("place_pressed", false))
	var input_b: PlayerInputFrame = frame_b.get("frame")
	_queue_client_frame(client_b, input_b)
	predictor_b.record_local_input(input_b, blocking_summary, grid)


func _sample_player_input(
	client: ClientSession,
	tick_id: int,
	up_key: Key,
	down_key: Key,
	left_key: Key,
	right_key: Key,
	place_key: Key,
	last_place_pressed: bool
) -> Dictionary:
	var move_x := 0
	var move_y := 0

	if Input.is_physical_key_pressed(left_key):
		move_x -= 1
	if Input.is_physical_key_pressed(right_key):
		move_x += 1
	if Input.is_physical_key_pressed(up_key):
		move_y -= 1
	if Input.is_physical_key_pressed(down_key):
		move_y += 1

	if move_x != 0:
		move_y = 0

	var place_pressed := Input.is_physical_key_pressed(place_key)
	var action_place := place_pressed and not last_place_pressed

	return {
		"frame": client.sample_input_for_tick(tick_id, move_x, move_y, action_place),
		"place_pressed": place_pressed
	}


func _queue_client_frame(client: ClientSession, frame: PlayerInputFrame) -> void:
	if client == null or frame == null:
		return

	client.send_input(frame)
	for outgoing in client.flush_outgoing_inputs():
		pipe.queue_input(outgoing)


func _queue_server_messages(messages: Array[Dictionary]) -> void:
	for message in messages:
		pipe.queue_client_message(client_a.local_peer_id, message)
		pipe.queue_client_message(client_b.local_peer_id, message)


func _flush_client_message_queue() -> void:
	_apply_client_messages(client_a, predictor_a, pipe.flush_client_messages(client_a.local_peer_id))
	_apply_client_messages(client_b, predictor_b, pipe.flush_client_messages(client_b.local_peer_id))


func _apply_client_messages(client: ClientSession, predictor: Phase2PredictedClient, messages: Array[Dictionary]) -> void:
	for message in messages:
		var msg_type := String(message.get("msg_type", ""))
		match msg_type:
			"INPUT_ACK":
				if int(message.get("peer_id", -1)) == client.local_peer_id:
					client.on_input_ack(int(message.get("ack_tick", -1)))
			"STATE_SUMMARY":
				client.on_state_summary(message)
				predictor.on_authoritative_state(
					int(message.get("tick", 0)),
					message.get("player_summary", []),
					int(message.get("checksum", 0)),
					server.active_match.build_player_position_summary(),
					server.active_match.sim_world.state.grid
				)
			"CHECKPOINT":
				client.on_snapshot(message)
			_:
				pass


func _refresh_views() -> void:
	if server == null or server.active_match == null:
		return

	var world := server.active_match.sim_world
	var server_summary := server.active_match.build_player_position_summary()
	var visible_divergence := _build_divergence_metrics(server_summary)
	var predicted_divergence := _build_predicted_divergence_metrics(server_summary)
	var match_result_text := _build_match_result_text(world)
	_last_metrics = {
		"match_phase_text": _match_phase_to_text(world.state.match_state.phase),
		"match_result_text": match_result_text,
		"server_tick": world.state.match_state.tick,
		"local_tick": world.state.match_state.tick,
		"predicted_tick": max(predictor_a.predicted_tick, predictor_b.predicted_tick),
		"snapshot_tick": max(client_a.latest_snapshot_tick, client_b.latest_snapshot_tick),
		"ack_a": client_a.last_confirmed_tick,
		"ack_b": client_b.last_confirmed_tick,
		"checksum": server.active_match.compute_checksum(world.state.match_state.tick),
		"checksum_a": client_a.latest_checksum,
		"checksum_b": client_b.latest_checksum,
		"rollback_count": predictor_a.correction_count + predictor_b.correction_count,
		"resync_count": 0,
		"prediction_enabled": true,
		"smoothing_enabled": false,
		"latency_ms": pipe.latency_ms,
		"packet_loss_percent": int(round(pipe.packet_loss * 100.0)),
		"server_positions": _summaries_to_lines(server_summary),
		"client_a_positions": _summaries_to_lines(client_a.latest_player_summary),
		"client_b_positions": _summaries_to_lines(client_b.latest_player_summary),
		"predicted_a_positions": predictor_a.build_predicted_lines(),
		"predicted_b_positions": predictor_b.build_predicted_lines(),
		"diverged": visible_divergence.get("diverged", false),
		"divergence_lines": visible_divergence.get("lines", []),
		"predicted_diverged": predicted_divergence.get("diverged", false),
		"predicted_divergence_lines": predicted_divergence.get("lines", []),
		"sync_note": _build_sync_note(server_summary),
		"prediction_note_a": predictor_a.get_prediction_gap_text() if predictor_a.has_prediction_gap() else "P1 confirmed == predicted",
		"prediction_note_b": predictor_b.get_prediction_gap_text() if predictor_b.has_prediction_gap() else "P2 confirmed == predicted",
		"correction_a": predictor_a.correction_count,
		"correction_b": predictor_b.correction_count,
		"item_count": world.state.items.active_ids.size()
	}

	if presentation_root != null:
		presentation_root.render_world(world, world.events.get_events(), _last_metrics)
	if simple_hud != null:
		simple_hud.apply_metrics(_last_metrics)
	if net_debug_overlay != null:
		net_debug_overlay.apply_metrics(_last_metrics)
	if result_banner != null:
		result_banner.apply_result(match_result_text, world.state.match_state.phase == MatchState.Phase.ENDED)


func _build_divergence_metrics(server_summary: Array[Dictionary]) -> Dictionary:
	var lines: Array[String] = []
	var server_map := _summary_to_slot_map(server_summary)
	var client_a_map := _summary_to_slot_map(client_a.latest_player_summary)
	var client_b_map := _summary_to_slot_map(client_b.latest_player_summary)

	for slot in server_map.keys():
		var server_entry: Dictionary = server_map[slot]
		var client_a_entry: Dictionary = client_a_map.get(slot, {})
		var client_b_entry: Dictionary = client_b_map.get(slot, {})
		var server_pos: Vector2i = server_entry.get("grid_pos", Vector2i(-1, -1))
		var client_a_pos: Vector2i = client_a_entry.get("grid_pos", Vector2i(-1, -1))
		var client_b_pos: Vector2i = client_b_entry.get("grid_pos", Vector2i(-1, -1))
		if client_a_pos != server_pos:
			lines.append("P%d A!=S %s/%s" % [int(slot) + 1, str(client_a_pos), str(server_pos)])
		if client_b_pos != server_pos:
			lines.append("P%d B!=S %s/%s" % [int(slot) + 1, str(client_b_pos), str(server_pos)])

	return {
		"diverged": lines.size() > 0,
		"lines": lines
	}


func _build_predicted_divergence_metrics(server_summary: Array[Dictionary]) -> Dictionary:
	var lines: Array[String] = []
	var server_map := _summary_to_slot_map(server_summary)
	var pred_a_map := _summary_to_slot_map(predictor_a.predicted_summary)
	var pred_b_map := _summary_to_slot_map(predictor_b.predicted_summary)

	for slot in server_map.keys():
		var server_pos: Vector2i = server_map[slot].get("grid_pos", Vector2i(-1, -1))
		var pred_a_pos: Vector2i = pred_a_map.get(slot, {}).get("grid_pos", Vector2i(-1, -1))
		var pred_b_pos: Vector2i = pred_b_map.get(slot, {}).get("grid_pos", Vector2i(-1, -1))
		if pred_a_pos != Vector2i(-1, -1) and pred_a_pos != server_pos:
			lines.append("P%d PredA!=S %s/%s" % [int(slot) + 1, str(pred_a_pos), str(server_pos)])
		if pred_b_pos != Vector2i(-1, -1) and pred_b_pos != server_pos:
			lines.append("P%d PredB!=S %s/%s" % [int(slot) + 1, str(pred_b_pos), str(server_pos)])

	return {
		"diverged": lines.size() > 0,
		"lines": lines
	}


func _summary_to_slot_map(summary: Array[Dictionary]) -> Dictionary:
	var slot_map: Dictionary = {}
	for entry in summary:
		var slot := int(entry.get("player_slot", -1))
		if slot >= 0:
			slot_map[slot] = entry
	return slot_map


func _summaries_to_lines(summary: Array[Dictionary]) -> Array[String]:
	var lines: Array[String] = []
	var slot_map := _summary_to_slot_map(summary)
	var slots := slot_map.keys()
	slots.sort()
	for slot in slots:
		var entry: Dictionary = slot_map[slot]
		var grid_pos: Vector2i = entry.get("grid_pos", Vector2i(-1, -1))
		lines.append("P%d %s" % [int(slot) + 1, str(grid_pos)])
	return lines


func _build_sync_note(server_summary: Array[Dictionary]) -> String:
	if server_summary.is_empty():
		return "waiting"
	if client_a.latest_player_summary.is_empty() or client_b.latest_player_summary.is_empty():
		return "clients waiting for first state"
	if _build_divergence_metrics(server_summary).get("diverged", false):
		return "client visible state differs from server"
	return "client-visible state matches server"


func _match_phase_to_text(phase: int) -> String:
	match phase:
		MatchState.Phase.BOOTSTRAP:
			return "BOOTSTRAP"
		MatchState.Phase.COUNTDOWN:
			return "COUNTDOWN"
		MatchState.Phase.PLAYING:
			return "PLAYING"
		MatchState.Phase.ENDING:
			return "ENDING"
		MatchState.Phase.ENDED:
			return "ENDED"
		_:
			return "UNKNOWN"


func _build_match_result_text(world: SimWorld) -> String:
	if world == null:
		return "pending"
	if world.state.match_state.phase != MatchState.Phase.ENDED:
		return "pending"

	var winner_player_id := world.state.match_state.winner_player_id
	if winner_player_id < 0:
		return "Draw"

	var winner := world.state.players.get_player(winner_player_id)
	if winner == null:
		return "Winner Unknown"
	return "Player %d Wins" % [winner.player_slot + 1]


func _handle_debug_shortcuts() -> void:
	_handle_one_shot_key(KEY_F5, Callable(self, "restart_match"))
	_handle_one_shot_key(KEY_F6, Callable(self, "cycle_latency_profile"))
	_handle_one_shot_key(KEY_F7, Callable(self, "cycle_loss_profile"))
	_handle_one_shot_key(KEY_P, Callable(self, "toggle_pause"))
	_handle_one_shot_key(KEY_O, Callable(self, "request_single_step"))


func _handle_one_shot_key(keycode: Key, callback: Callable) -> void:
	var pressed := Input.is_physical_key_pressed(keycode)
	var was_pressed := bool(_last_debug_pressed.get(keycode, false))
	if pressed and not was_pressed:
		callback.call()
	_last_debug_pressed[keycode] = pressed
