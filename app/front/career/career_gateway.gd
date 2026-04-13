class_name CareerGateway
extends RefCounted


func configure_base_url(base_url: String) -> void:
	pass


func fetch_my_career(access_token: String) -> Dictionary:
	return {
		"ok": false,
		"error_code": "NOT_IMPLEMENTED",
		"user_message": "CareerGateway.fetch_my_career not implemented",
	}
