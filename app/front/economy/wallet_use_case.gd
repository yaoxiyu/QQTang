class_name WalletUseCase
extends RefCounted

const WalletStateScript = preload("res://app/front/economy/wallet_state.gd")
const ServiceUrlBuilderScript = preload("res://app/infra/http/service_url_builder.gd")

var auth_session_state: AuthSessionState = null
var front_settings_state: FrontSettingsState = null
var wallet_gateway: RefCounted = null
var current_wallet: RefCounted = null


func configure(p_auth_session_state: AuthSessionState, p_front_settings_state: FrontSettingsState, p_wallet_gateway: RefCounted) -> void:
	auth_session_state = p_auth_session_state
	front_settings_state = p_front_settings_state
	wallet_gateway = p_wallet_gateway


func refresh_wallet() -> Dictionary:
	if auth_session_state == null or auth_session_state.access_token.strip_edges().is_empty():
		return _fail("AUTH_SESSION_INVALID", "Access session is not available")
	if wallet_gateway == null or not wallet_gateway.has_method("fetch_my_wallet"):
		return _fail("WALLET_GATEWAY_MISSING", "Wallet gateway is not available")
	_configure_gateway()
	var response = await wallet_gateway.fetch_my_wallet(auth_session_state.access_token)
	if not bool(response.get("ok", false)):
		return _fail(String(response.get("error_code", "WALLET_FETCH_FAILED")), String(response.get("user_message", "Failed to fetch wallet")))
	current_wallet = WalletStateScript.from_response(response)
	return {"ok": true, "wallet": current_wallet}


func get_current_wallet():
	return current_wallet


func _configure_gateway() -> void:
	if front_settings_state == null:
		return
	if wallet_gateway != null and wallet_gateway.has_method("configure_base_url"):
		wallet_gateway.configure_base_url(ServiceUrlBuilderScript.build_account_base_url(front_settings_state.account_service_host, front_settings_state.account_service_port, 18080))


func _fail(error_code: String, user_message: String) -> Dictionary:
	return {"ok": false, "error_code": error_code, "user_message": user_message}
