class_name DsLifecycleReporter
extends RefCounted

const LogNetScript = preload("res://app/logging/log_net.gd")

var battle_id: String = ""
var dev_mode: bool = false
var active_reported: bool = false
var _manifest_client = null
var _http_client
var _auth_signer = null
var _authority_host: String = "127.0.0.1"
var _listen_port: int = 9000
var _ds_manager_base_url: String = ""


func configure(manifest_client, http_client, auth_signer, battle_id_in: String, authority_host_in: String, listen_port_in: int, ds_manager_base_url_in: String, dev_mode_in: bool) -> void:
	_manifest_client = manifest_client
	_http_client = http_client
	_auth_signer = auth_signer
	battle_id = battle_id_in
	_authority_host = authority_host_in
	_listen_port = listen_port_in
	_ds_manager_base_url = ds_manager_base_url_in
	dev_mode = dev_mode_in


func report_battle_ready(manifest_client) -> void:
	if dev_mode:
		LogNetScript.info("battle_ready reported (dev mode stub) battle_id=%s" % battle_id, "", 0, "net.battle_ds_bootstrap")
		return
	if battle_id.is_empty():
		return
	if manifest_client == null:
		LogNetScript.info("battle_ready reported (stub, no client) battle_id=%s" % battle_id, "", 0, "net.battle_ds_bootstrap")
		return
	var result: Dictionary = await manifest_client.post_ready(battle_id, _authority_host, _listen_port)
	if not bool(result.get("ok", false)):
		LogNetScript.warn("battle_ready report failed: %s %s" % [String(result.get("error_code", "")), String(result.get("user_message", ""))], "", 0, "net.battle_ds_bootstrap")
	else:
		LogNetScript.info("battle_ready reported ok battle_id=%s" % battle_id, "", 0, "net.battle_ds_bootstrap")
	await report_ds_instance_ready()


func report_ds_instance_ready() -> void:
	if dev_mode:
		return
	if battle_id.is_empty() or _ds_manager_base_url.is_empty():
		return
	var path := "/internal/v1/battles/%s/ready" % battle_id.uri_encode()
	var result := await _send_plain_json_request(_ds_manager_base_url, path, {})
	if not bool(result.get("ok", false)):
		LogNetScript.warn("ds_manager ready report failed: %s %s" % [String(result.get("error_code", "")), String(result.get("user_message", ""))], "", 0, "net.battle_ds_bootstrap")
	else:
		LogNetScript.info("ds_manager ready reported ok battle_id=%s" % battle_id, "", 0, "net.battle_ds_bootstrap")


func report_ds_instance_active() -> void:
	if dev_mode:
		return
	if active_reported or battle_id.is_empty() or _ds_manager_base_url.is_empty():
		return
	var path := "/internal/v1/battles/%s/active" % battle_id.uri_encode()
	var result := await _send_plain_json_request(_ds_manager_base_url, path, {})
	if not bool(result.get("ok", false)):
		LogNetScript.warn("ds_manager active report failed: %s %s" % [String(result.get("error_code", "")), String(result.get("user_message", ""))], "", 0, "net.battle_ds_bootstrap")
		return
	active_reported = true
	LogNetScript.info("ds_manager active reported ok battle_id=%s" % battle_id, "", 0, "net.battle_ds_bootstrap")


func _send_plain_json_request(base_url: String, path: String, payload: Dictionary) -> Dictionary:
	if base_url.strip_edges().is_empty():
		return _plain_json_fail("PLAIN_JSON_URL_INVALID", "Target url is invalid")
	if _auth_signer == null or _http_client == null:
		return _plain_json_fail("PLAIN_JSON_AUTH_MISSING", "DSM internal auth signer is missing")
	var result: Dictionary = await _http_client.post_json(path, payload)
	if bool(result.get("ok", false)):
		return result
	match String(result.get("error_code", "")):
		"INTERNAL_JSON_URL_INVALID", "INTERNAL_JSON_URL_MISSING":
			return _plain_json_fail("PLAIN_JSON_URL_INVALID", "Target url is invalid")
		"INTERNAL_JSON_CONNECT_FAILED":
			return _plain_json_fail("PLAIN_JSON_CONNECT_FAILED", "Failed to connect target service")
		"INTERNAL_JSON_REQUEST_FAILED":
			return _plain_json_fail("PLAIN_JSON_REQUEST_FAILED", "Failed to send request")
		"INTERNAL_JSON_EMPTY_RESPONSE":
			return _plain_json_fail("PLAIN_JSON_EMPTY_RESPONSE", "Target service returned empty response")
		"INTERNAL_JSON_RESPONSE_INVALID":
			return _plain_json_fail("PLAIN_JSON_RESPONSE_INVALID", "Target service returned invalid response")
		_:
			return result


func _plain_json_fail(error_code: String, user_message: String) -> Dictionary:
	return {"ok": false, "error_code": error_code, "user_message": user_message}
