class_name InventoryUseCase
extends RefCounted

const PlayerInventoryStateScript = preload("res://app/front/inventory/player_inventory_state.gd")

var auth_session_state: AuthSessionState = null
var front_settings_state: FrontSettingsState = null
var inventory_gateway: RefCounted = null
var current_inventory: RefCounted = null


func configure(p_auth_session_state: AuthSessionState, p_front_settings_state: FrontSettingsState, p_inventory_gateway: RefCounted) -> void:
	auth_session_state = p_auth_session_state
	front_settings_state = p_front_settings_state
	inventory_gateway = p_inventory_gateway


func refresh_inventory() -> Dictionary:
	if auth_session_state == null or auth_session_state.access_token.strip_edges().is_empty():
		return _fail("AUTH_SESSION_INVALID", "Access session is not available")
	if inventory_gateway == null or not inventory_gateway.has_method("fetch_my_inventory"):
		return _fail("INVENTORY_GATEWAY_MISSING", "Inventory gateway is not available")
	_configure_gateway()
	var response = inventory_gateway.fetch_my_inventory(auth_session_state.access_token)
	if not bool(response.get("ok", false)):
		return _fail(String(response.get("error_code", "INVENTORY_FETCH_FAILED")), String(response.get("user_message", "Failed to fetch inventory")))
	current_inventory = PlayerInventoryStateScript.from_response(response)
	return {"ok": true, "inventory": current_inventory}


func get_current_inventory():
	return current_inventory


func _configure_gateway() -> void:
	if front_settings_state == null:
		return
	if inventory_gateway != null and inventory_gateway.has_method("configure_base_url"):
		inventory_gateway.configure_base_url("http://%s:%d" % [front_settings_state.account_service_host, front_settings_state.account_service_port])


func _fail(error_code: String, user_message: String) -> Dictionary:
	return {"ok": false, "error_code": error_code, "user_message": user_message}
