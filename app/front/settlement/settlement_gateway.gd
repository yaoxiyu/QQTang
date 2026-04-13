class_name SettlementGateway
extends RefCounted


func configure_base_url(base_url: String) -> void:
	pass


func fetch_match_summary(access_token: String, match_id: String) -> Dictionary:
	return {
		"ok": false,
		"error_code": "NOT_IMPLEMENTED",
		"user_message": "SettlementGateway.fetch_match_summary not implemented",
	}
