extends "res://network/runtime/battle_dedicated_server_bootstrap.gd"

class_name BattleBootstrapProbe

var sent_messages: Array[Dictionary] = []
var battle_messages_routed: int = 0


func _send_to_peer(peer_id: int, message: Dictionary) -> void:
	sent_messages.append({
		"peer_id": peer_id,
		"message": message.duplicate(true),
	})


func latest_for_peer(peer_id: int, message_type: String) -> Dictionary:
	for index in range(sent_messages.size() - 1, -1, -1):
		var entry: Dictionary = sent_messages[index]
		if int(entry.get("peer_id", 0)) != peer_id:
			continue
		var message: Dictionary = entry.get("message", {})
		if String(message.get("message_type", "")) == message_type:
			return message
	return {}
