class_name RemoteDebugInputDriver
extends RefCounted

var _owner: Node = null
var _remote_clients: Array = []


func setup(owner: Node, config: BattleStartConfig, local_peer_id: int) -> void:
	shutdown()
	_owner = owner
	if owner == null or config == null:
		return
	for player_entry in config.players:
		var peer_id: int = int(player_entry.get("peer_id", -1))
		if peer_id < 0 or peer_id == local_peer_id:
			continue
		var remote_client := ClientSession.new()
		remote_client.configure(peer_id)
		owner.add_child(remote_client)
		_remote_clients.append(remote_client)


func shutdown() -> void:
	for remote_client in _remote_clients:
		if remote_client != null and is_instance_valid(remote_client):
			remote_client.free()
	_remote_clients.clear()
	_owner = null


func enqueue_inputs(tick_id: int, use_debug_pattern: bool) -> void:
	for remote_client in _remote_clients:
		if remote_client == null:
			continue
		if not use_debug_pattern:
			remote_client.send_input(remote_client.sample_input_for_tick(tick_id, 0, 0, false))
			continue
		var remote_input: Dictionary = _sample_debug_input(remote_client.local_peer_id, tick_id)
		remote_client.send_input(
			remote_client.sample_input_for_tick(
				tick_id,
				int(remote_input.get("move_x", 0)),
				int(remote_input.get("move_y", 0)),
				int(remote_input.get("action_bits", 0))
			)
		)


func flush_to_server(server_session: ServerSession) -> void:
	if server_session == null:
		return
	for remote_client in _remote_clients:
		if remote_client == null:
			continue
		for frame in remote_client.flush_outgoing_inputs():
			server_session.receive_input(frame)


func has_remote_clients() -> bool:
	return not _remote_clients.is_empty()


func _sample_debug_input(peer_id: int, tick_id: int) -> Dictionary:
	var phase: int = int((tick_id / 24 + peer_id) % 4)
	var move_x: int = 0
	var move_y: int = 0
	match phase:
		0:
			move_x = 1
		1:
			move_y = 1
		2:
			move_x = -1
		3:
			move_y = -1
	var place_action: bool = tick_id > 20 and tick_id % 45 == (peer_id % 5)
	return {
		"move_x": move_x,
		"move_y": move_y,
		"action_bits": PlayerInputFrame.BIT_PLACE if place_action else 0,
	}
