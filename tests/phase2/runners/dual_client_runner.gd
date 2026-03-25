class_name DualClientRunner
extends Node

const ServerSessionScript = preload("res://gameplay/network/session/server_session.gd")
const ClientSessionScript = preload("res://gameplay/network/session/client_session.gd")

var server: ServerSession = null
var client_a: ClientSession = null
var client_b: ClientSession = null


func setup(peer_a: int = 101, peer_b: int = 202, seed: int = 1, map_data = null) -> void:
	server = ServerSessionScript.new()
	client_a = ClientSessionScript.new()
	client_b = ClientSessionScript.new()
	add_child(server)
	add_child(client_a)
	add_child(client_b)

	client_a.configure(peer_a)
	client_b.configure(peer_b)
	server.create_room("dual_client_runner", "basic_map", "default")
	server.add_peer(peer_a)
	server.add_peer(peer_b)
	server.set_peer_ready(peer_a, true)
	server.set_peer_ready(peer_b, true)
	server.start_match(SimConfig.new(), {"grid": map_data if map_data != null else TestMapFactory.build_basic_map()}, seed, 0)


func consume_server_messages() -> Array[Dictionary]:
	return server.poll_messages()
