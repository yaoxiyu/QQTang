class_name ShopGateway
extends RefCounted


func fetch_catalog(_access_token: String, _if_none_match: int = 0) -> Dictionary:
	return {"ok": false, "error_code": "NOT_IMPLEMENTED", "user_message": "ShopGateway.fetch_catalog not implemented"}


func purchase_offer(_access_token: String, _offer_id: String, _idempotency_key: String, _expected_catalog_revision: int) -> Dictionary:
	return {"ok": false, "error_code": "NOT_IMPLEMENTED", "user_message": "ShopGateway.purchase_offer not implemented"}
