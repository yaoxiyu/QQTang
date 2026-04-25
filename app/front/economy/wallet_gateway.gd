class_name WalletGateway
extends RefCounted


func fetch_my_wallet(access_token: String) -> Dictionary:
	return {
		"ok": false,
		"error_code": "NOT_IMPLEMENTED",
		"user_message": "WalletGateway.fetch_my_wallet not implemented",
	}
