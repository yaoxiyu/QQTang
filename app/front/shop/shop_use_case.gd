class_name ShopUseCase
extends RefCounted

const ShopCatalogStateScript = preload("res://app/front/shop/shop_catalog_state.gd")
const PurchaseResultStateScript = preload("res://app/front/shop/purchase_result_state.gd")

var auth_session_state: AuthSessionState = null
var front_settings_state: FrontSettingsState = null
var shop_gateway: RefCounted = null
var current_catalog: RefCounted = null
var last_purchase_result: RefCounted = null


func configure(p_auth_session_state: AuthSessionState, p_front_settings_state: FrontSettingsState, p_shop_gateway: RefCounted) -> void:
	auth_session_state = p_auth_session_state
	front_settings_state = p_front_settings_state
	shop_gateway = p_shop_gateway


func refresh_catalog() -> Dictionary:
	if auth_session_state == null or auth_session_state.access_token.strip_edges().is_empty():
		return _fail("AUTH_SESSION_INVALID", "Access session is not available")
	if shop_gateway == null or not shop_gateway.has_method("fetch_catalog"):
		return _fail("SHOP_GATEWAY_MISSING", "Shop gateway is not available")
	_configure_gateway()
	var revision: int = current_catalog.catalog_revision if current_catalog != null else 0
	var response = shop_gateway.fetch_catalog(auth_session_state.access_token, revision)
	if not bool(response.get("ok", false)):
		return _fail(String(response.get("error_code", "SHOP_CATALOG_FETCH_FAILED")), String(response.get("user_message", "Failed to fetch shop catalog")))
	current_catalog = ShopCatalogStateScript.from_response(response, current_catalog)
	return {"ok": true, "catalog": current_catalog, "not_modified": bool(response.get("not_modified", false))}


func purchase_offer(offer_id: String, idempotency_key: String = "") -> Dictionary:
	if current_catalog == null:
		return _fail("SHOP_CATALOG_MISSING", "Shop catalog is not loaded")
	if auth_session_state == null or auth_session_state.access_token.strip_edges().is_empty():
		return _fail("AUTH_SESSION_INVALID", "Access session is not available")
	if shop_gateway == null or not shop_gateway.has_method("purchase_offer"):
		return _fail("SHOP_GATEWAY_MISSING", "Shop gateway is not available")
	var key := idempotency_key.strip_edges()
	if key.is_empty():
		key = "client_%d_%s" % [Time.get_ticks_usec(), offer_id]
	_configure_gateway()
	var response = shop_gateway.purchase_offer(auth_session_state.access_token, offer_id, key, current_catalog.catalog_revision)
	if not bool(response.get("ok", false)):
		return _fail(String(response.get("error_code", "PURCHASE_FAILED")), String(response.get("user_message", "Purchase failed")))
	last_purchase_result = PurchaseResultStateScript.from_response(response)
	return {"ok": true, "purchase": last_purchase_result}


func _configure_gateway() -> void:
	if front_settings_state == null:
		return
	if shop_gateway != null and shop_gateway.has_method("configure_base_url"):
		shop_gateway.configure_base_url("http://%s:%d" % [front_settings_state.account_service_host, front_settings_state.account_service_port])


func _fail(error_code: String, user_message: String) -> Dictionary:
	return {"ok": false, "error_code": error_code, "user_message": user_message}
