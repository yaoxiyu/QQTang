extends "res://tests/gut/base/qqt_unit_test.gd"

const LocalLoopbackTransportScript = preload("res://network/transport/local_loopback_transport.gd")
const TransportMessageTypesScript = preload("res://network/transport/transport_message_types.gd")


func test_main() -> void:
	var ok := true
	ok = _test_send_receive_roundtrip() and ok
	ok = _test_latency_profile_delays_delivery() and ok
	ok = _test_packet_loss_profile_drops_droppable_messages() and ok


func _test_send_receive_roundtrip() -> bool:
	var transport := LocalLoopbackTransportScript.new()
	add_child(transport)
	transport.initialize({
		"is_server": true,
		"local_peer_id": 1,
		"remote_peer_ids": [2],
		"current_tick": 10,
		"seed": 11,
	})
	transport.send_to_peer(2, {
		"message_type": TransportMessageTypesScript.STATE_SUMMARY,
		"tick": 10,
		"protocol_version": 1,
	})
	transport.poll()
	var incoming := transport.consume_incoming()
	var stats := transport.get_debug_stats()
	var prefix := "local_loopback_transport_test"
	var ok := true
	ok = qqt_check(incoming.size() == 1, "loopback should deliver a sent message", prefix) and ok
	ok = qqt_check(String(incoming[0].get("message_type", "")) == TransportMessageTypesScript.STATE_SUMMARY, "delivered message should preserve message_type", prefix) and ok
	ok = qqt_check(int(incoming[0].get("tick", 0)) == 10, "delivered message should preserve tick", prefix) and ok
	ok = qqt_check(int(stats.get("enqueued", 0)) == 1, "enqueued stat should increment after send", prefix) and ok
	ok = qqt_check(int(stats.get("delivered", 0)) == 1, "delivered stat should increment after poll", prefix) and ok
	transport.shutdown()
	transport.queue_free()
	return ok


func _test_latency_profile_delays_delivery() -> bool:
	var transport := LocalLoopbackTransportScript.new()
	add_child(transport)
	transport.initialize({
		"is_server": true,
		"local_peer_id": 1,
		"remote_peer_ids": [2],
		"current_tick": 100,
		"seed": 22,
	})
	transport.cycle_latency_profile()
	transport.send_to_peer(2, {
		"message_type": TransportMessageTypesScript.INPUT_ACK,
		"ack_tick": 100,
	})
	transport.poll()
	var prefix := "local_loopback_transport_test"
	var ok := true
	ok = qqt_check(transport.get_latency_profile_ms() == 80, "latency profile should cycle to 80ms", prefix) and ok
	ok = qqt_check(transport.consume_incoming().is_empty(), "message should not arrive on the same tick when latency is enabled", prefix) and ok
	var delayed: Array[Dictionary] = []
	for tick_id in [101, 102, 103, 104]:
		transport.set_current_tick(tick_id)
		transport.poll()
		delayed = transport.consume_incoming()
		if not delayed.is_empty():
			break
	ok = qqt_check(delayed.size() == 1, "message should arrive after enough delayed ticks", prefix) and ok
	transport.shutdown()
	transport.queue_free()
	return ok


func _test_packet_loss_profile_drops_droppable_messages() -> bool:
	var transport := LocalLoopbackTransportScript.new()
	add_child(transport)
	transport.initialize({
		"is_server": true,
		"local_peer_id": 1,
		"remote_peer_ids": [2],
		"current_tick": 0,
		"seed": 1,
	})
	transport.apply_debug_profile({
		"latency_profile_index": 0,
		"loss_profile_index": 3,
	})
	for tick_id in range(200):
		transport.send_to_peer(2, {
			"message_type": TransportMessageTypesScript.STATE_SUMMARY,
			"tick": tick_id,
		})
	transport.send_to_peer(2, {
		"message_type": TransportMessageTypesScript.MATCH_FINISHED,
		"tick": 201,
	})
	transport.poll()
	var incoming := transport.consume_incoming()
	var stats := transport.get_debug_stats()
	var saw_non_droppable := false
	for message in incoming:
		if String(message.get("message_type", "")) == TransportMessageTypesScript.MATCH_FINISHED:
			saw_non_droppable = true
			break
	var prefix := "local_loopback_transport_test"
	var ok := true
	ok = qqt_check(transport.get_packet_loss_percent() == 20, "loss profile should cycle to 20 percent", prefix) and ok
	ok = qqt_check(int(stats.get("dropped", 0)) > 0, "droppable messages should be dropped under loss profile", prefix) and ok
	ok = qqt_check(saw_non_droppable, "non-droppable messages should still be delivered under loss profile", prefix) and ok
	transport.shutdown()
	transport.queue_free()
	return ok

