class_name DsDevAiBridge
extends RefCounted

const LogNetScript = preload("res://app/logging/log_net.gd")
const TickRunnerScript = preload("res://gameplay/simulation/runtime/tick_runner.gd")
const PlayerInputFrameScript = preload("res://gameplay/simulation/input/player_input_frame.gd")
const AiInputDriverScript = preload("res://gameplay/simulation/systems/ai_input_driver.gd")

var ai_inputs_enabled: bool = true
var pending_ai_ready: bool = false
var _drivers: Dictionary = {}
var _pending_opening_ack_frames: int = 0
var _tick_counter: int = 0
var _tick_accumulator: float = 0.0
var _battle_runtime: Node = null
var _transport = null
var _match_id: String = ""
var _transport_message_types_script = null


func configure(battle_runtime: Node, transport, match_id: String, transport_message_types_script) -> void:
	_battle_runtime = battle_runtime
	_transport = transport
	_match_id = match_id
	_transport_message_types_script = transport_message_types_script


func create_ai_driver(peer_id: int) -> void:
	if _drivers.has(peer_id):
		return
	var driver := AiInputDriverScript.new()
	driver.configure(peer_id)
	_drivers[peer_id] = driver


func has_driver(peer_id: int) -> bool:
	return _drivers.has(peer_id)


func toggle(enabled: bool = false, has_explicit: bool = false) -> void:
	if has_explicit:
		ai_inputs_enabled = enabled
	else:
		ai_inputs_enabled = not ai_inputs_enabled
	LogNetScript.info("dev_toggle_ai applied enabled=%s" % str(ai_inputs_enabled), "", 0, "net.battle_ds_bootstrap")


func flag_pending_ai_ready() -> void:
	pending_ai_ready = true


func set_match_id(match_id: String) -> void:
	_match_id = match_id


func clear() -> void:
	_drivers.clear()
	_tick_counter = 0
	_tick_accumulator = 0.0
	pending_ai_ready = false
	_pending_opening_ack_frames = 0


func process_tick(delta: float, joined_peer_ids: Array[int]) -> void:
	if _battle_runtime == null:
		return
	_tick_accumulator += delta
	var tick_dt: float = TickRunnerScript.TICK_DT
	while _tick_accumulator >= tick_dt:
		_tick_accumulator -= tick_dt
		_tick_counter += 1
		if not ai_inputs_enabled:
			continue
		_inject_ai_inputs(joined_peer_ids)

	if pending_ai_ready:
		pending_ai_ready = false
		_send_fake_loading_ready()

	if _pending_opening_ack_frames > 0:
		_pending_opening_ack_frames -= 1
		if _pending_opening_ack_frames == 0:
			_send_fake_opening_ack()


func _inject_ai_inputs(joined_peer_ids: Array[int]) -> void:
	for peer_id in joined_peer_ids:
		var driver: AiInputDriver = _drivers.get(peer_id, null)
		if driver == null:
			continue
		var ai_input := driver.sample_input_for_tick(_tick_counter)
		var server_session = _resolve_server_session()
		if server_session == null:
			continue
		var authority_tick: int = _get_authority_tick(server_session)
		if authority_tick < 0:
			continue
		var ai_frame := PlayerInputFrameScript.new()
		ai_frame.peer_id = peer_id
		ai_frame.tick_id = authority_tick + 1
		ai_frame.seq = ai_frame.tick_id
		ai_frame.move_x = int(ai_input.get("move_x", 0))
		ai_frame.move_y = int(ai_input.get("move_y", 0))
		ai_frame.action_bits = int(ai_input.get("action_bits", 0))
		ai_frame.sanitize()
		server_session.receive_input(ai_frame)


func _send_fake_loading_ready() -> void:
	for ai_peer_id in _drivers.keys():
		LogNetScript.info("dev_loading: fake MATCH_LOADING_READY for AI peer=%d" % int(ai_peer_id), "", 0, "net.battle_ds_bootstrap")
		_battle_runtime.handle_loading_message({
			"message_type": _transport_message_types_script.MATCH_LOADING_READY,
			"sender_peer_id": int(ai_peer_id),
			"match_id": _match_id,
			"revision": 1,
		})
	_pending_opening_ack_frames = 2


func _send_fake_opening_ack() -> void:
	for ai_peer_id in _drivers.keys():
		LogNetScript.info("dev_loading: fake OPENING_SNAPSHOT_ACK for AI peer=%d" % int(ai_peer_id), "", 0, "net.battle_ds_bootstrap")
		_battle_runtime.handle_battle_message({
			"message_type": _transport_message_types_script.OPENING_SNAPSHOT_ACK,
			"sender_peer_id": int(ai_peer_id),
		})


func _resolve_server_session():
	if _battle_runtime == null:
		return null
	var match_service = _battle_runtime.get_match_service() if _battle_runtime.has_method("get_match_service") else null
	if match_service == null:
		return null
	var authority = match_service.get("_authority_runtime")
	if authority == null:
		return null
	return authority.get("server_session")


func _get_authority_tick(server_session) -> int:
	if server_session == null:
		return -1
	var active_match = server_session.get("active_match")
	if active_match == null:
		return -1
	var sim_world = active_match.get("sim_world")
	if sim_world == null:
		return -1
	var state = sim_world.get("state")
	if state == null:
		return -1
	var match_state = state.get("match_state")
	if match_state == null:
		return -1
	return int(match_state.get("tick"))
