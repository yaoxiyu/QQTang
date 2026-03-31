class_name IBattleTransport
extends Node

@warning_ignore("unused_signal")
signal connected()
@warning_ignore("unused_signal")
signal disconnected()
@warning_ignore("unused_signal")
signal peer_connected(peer_id: int)
@warning_ignore("unused_signal")
signal peer_disconnected(peer_id: int)
@warning_ignore("unused_signal")
signal transport_error(code: int, message: String)


func initialize(_config: Dictionary = {}) -> void:
	push_warning("IBattleTransport.initialize() should be implemented by subclasses")


func shutdown() -> void:
	pass


func poll() -> void:
	pass


func is_server() -> bool:
	return false


func is_transport_connected() -> bool:
	return false


func get_local_peer_id() -> int:
	return 0


func get_remote_peer_ids() -> Array[int]:
	return []


func send_to_peer(_peer_id: int, _message: Dictionary) -> void:
	pass


func broadcast(_message: Dictionary) -> void:
	pass


func consume_incoming() -> Array[Dictionary]:
	return []


func cycle_latency_profile() -> int:
	return 0


func cycle_loss_profile() -> int:
	return 0


func get_latency_profile_ms() -> int:
	return 0


func get_packet_loss_percent() -> int:
	return 0


func get_network_profile_summary() -> String:
	return "0ms / 0%"


func get_debug_stats() -> Dictionary:
	return {
		"enqueued": 0,
		"delivered": 0,
		"dropped": 0,
	}
