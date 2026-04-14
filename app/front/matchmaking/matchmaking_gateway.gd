class_name MatchmakingGateway
extends RefCounted


func configure_base_url(base_url: String) -> void:
	pass


func enter_queue(access_token: String, queue_type: String, match_format_id: String, mode_id: String, rule_set_id: String, selected_map_ids: Array[String]):
	return {
		"ok": false,
		"error_code": "NOT_IMPLEMENTED",
		"user_message": "MatchmakingGateway.enter_queue not implemented",
	}


func cancel_queue(access_token: String, queue_entry_id: String = ""):
	return {
		"ok": false,
		"error_code": "NOT_IMPLEMENTED",
		"user_message": "MatchmakingGateway.cancel_queue not implemented",
	}


func get_queue_status(access_token: String, queue_entry_id: String = ""):
	return {
		"ok": false,
		"error_code": "NOT_IMPLEMENTED",
		"user_message": "MatchmakingGateway.get_queue_status not implemented",
	}
