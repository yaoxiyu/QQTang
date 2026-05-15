class_name DsLaunchConfig
extends RefCounted

const InternalAuthSignerScript = preload("res://network/services/internal_auth_signer.gd")
const InternalJsonServiceClientScript = preload("res://app/infra/http/internal_json_service_client.gd")
const InternalServiceAuthConfigScript = preload("res://app/infra/http/internal_service_auth_config.gd")
const ServiceUrlBuilderScript = preload("res://app/infra/http/service_url_builder.gd")
const LogNetScript = preload("res://app/logging/log_net.gd")

var battle_id: String = ""
var assignment_id: String = ""
var match_id: String = ""
var source_room_id: String = ""
var source_room_kind: String = ""
var season_id: String = ""
var listen_port: int = 9000
var authority_host: String = "127.0.0.1"
var battle_ticket_secret: String = "dev_battle_ticket_secret"
var resume_window_sec: float = 20.0

var dev_mode: bool = false
var dev_player_count: int = 2
var dev_map_id_override: String = ""
var dev_rule_set_id_override: String = ""

var ds_manager_base_url: String = ""
var ds_manager_auth_signer = null
var ds_manager_http_client = null
var config_errors: Array[String] = []
var _legacy_battle_ticket_secret_arg: String = ""


func parse(args: Array[String], export_defaults: Dictionary) -> void:
	config_errors.clear()
	_legacy_battle_ticket_secret_arg = ""
	listen_port = int(export_defaults.get("listen_port", 9000))
	authority_host = String(export_defaults.get("authority_host", "127.0.0.1"))
	battle_ticket_secret = String(export_defaults.get("battle_ticket_secret", "dev_battle_ticket_secret"))
	resume_window_sec = float(export_defaults.get("resume_window_sec", 20.0))

	_parse_args(args)
	_apply_legacy_battle_secret_policy()
	battle_ticket_secret = _resolve_battle_ticket_secret()
	_validate_runtime_security()
	ds_manager_base_url = _resolve_ds_manager_base_url()
	ds_manager_auth_signer = _build_ds_manager_auth_signer()
	ds_manager_http_client = _build_ds_manager_http_client(ds_manager_base_url)


func _parse_args(args: Array[String]) -> void:
	var parsed: Dictionary = {}
	for index in range(args.size()):
		var arg := String(args[index])
		if arg.begins_with("--qqt-") and arg.contains("="):
			var eq_pos := arg.find("=")
			parsed[arg.substr(0, eq_pos)] = arg.substr(eq_pos + 1)
		elif arg.begins_with("--qqt-") and index + 1 < args.size():
			parsed[arg] = String(args[index + 1])

	if parsed.has("--qqt-ds-port"):
		var parsed_port := int(String(parsed["--qqt-ds-port"]).to_int())
		if parsed_port > 0:
			listen_port = parsed_port
	if parsed.has("--qqt-ds-host"):
		var parsed_host := String(parsed["--qqt-ds-host"]).strip_edges()
		if not parsed_host.is_empty():
			authority_host = parsed_host
	if parsed.has("--qqt-battle-id"):
		battle_id = String(parsed["--qqt-battle-id"]).strip_edges()
	if parsed.has("--qqt-assignment-id"):
		assignment_id = String(parsed["--qqt-assignment-id"]).strip_edges()
	if parsed.has("--qqt-match-id"):
		match_id = String(parsed["--qqt-match-id"]).strip_edges()
	if parsed.has("--qqt-battle-ticket-secret"):
		var parsed_secret := String(parsed["--qqt-battle-ticket-secret"]).strip_edges()
		if not parsed_secret.is_empty():
			_legacy_battle_ticket_secret_arg = parsed_secret
	if parsed.has("--qqt-resume-window-sec"):
		var parsed_resume_window := float(String(parsed["--qqt-resume-window-sec"]).to_float())
		if parsed_resume_window > 0.0:
			resume_window_sec = parsed_resume_window

	if parsed.has("--qqt-dev-mode"):
		dev_mode = true
	if parsed.has("--qqt-dev-player-count"):
		var parsed_count := int(String(parsed["--qqt-dev-player-count"]).to_int())
		if parsed_count >= 2:
			dev_player_count = parsed_count
	if parsed.has("--qqt-dev-map-id"):
		dev_map_id_override = String(parsed["--qqt-dev-map-id"]).strip_edges()
	if parsed.has("--qqt-dev-rule-set-id"):
		dev_rule_set_id_override = String(parsed["--qqt-dev-rule-set-id"]).strip_edges()


func has_config_errors() -> bool:
	return not config_errors.is_empty()


func get_config_errors() -> Array[String]:
	return config_errors.duplicate()


func _apply_legacy_battle_secret_policy() -> void:
	if _legacy_battle_ticket_secret_arg.is_empty():
		return
	if dev_mode or _allow_legacy_secret_arg_override():
		battle_ticket_secret = _legacy_battle_ticket_secret_arg
		LogNetScript.warn("--qqt-battle-ticket-secret is legacy/dev only; prefer QQT_BATTLE_TICKET_SECRET or QQT_BATTLE_TICKET_SECRET_FILE", "", 0, "net.battle_ds_bootstrap")
		return
	config_errors.append("--qqt-battle-ticket-secret is blocked outside dev mode")


func _allow_legacy_secret_arg_override() -> bool:
	var value := OS.get_environment("QQT_ALLOW_LEGACY_DS_SECRET_ARG").strip_edges().to_lower()
	return value == "1" or value == "true" or value == "yes" or value == "on"


func _validate_runtime_security() -> void:
	if dev_mode:
		return
	if not _is_production_env():
		return
	if _is_unsafe_dev_secret(battle_ticket_secret):
		config_errors.append("QQT_BATTLE_TICKET_SECRET uses unsafe dev/default secret in production runtime")


func _resolve_battle_ticket_secret() -> String:
	var direct_secret := OS.get_environment("QQT_BATTLE_TICKET_SECRET").strip_edges()
	if not direct_secret.is_empty():
		return direct_secret
	var secret_file := OS.get_environment("QQT_BATTLE_TICKET_SECRET_FILE").strip_edges()
	if not secret_file.is_empty():
		var file_secret := _read_text_file(secret_file).strip_edges()
		if not file_secret.is_empty():
			return file_secret
	if battle_ticket_secret.strip_edges().is_empty():
		return "dev_battle_ticket_secret"
	return battle_ticket_secret


func _read_text_file(path: String) -> String:
	if path.strip_edges().is_empty():
		return ""
	if not FileAccess.file_exists(path):
		LogNetScript.warn("battle ticket secret file not found: %s" % path, "", 0, "net.battle_ds_bootstrap")
		return ""
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		LogNetScript.warn("battle ticket secret file cannot be opened: %s" % path, "", 0, "net.battle_ds_bootstrap")
		return ""
	return file.get_as_text()


func _resolve_ds_manager_base_url() -> String:
	var candidates := [
		_read_env("DSM_BASE_URL", ""),
		_read_env("DS_MANAGER_URL", ""),
		_read_env("GAME_DS_MANAGER_URL", ""),
		_read_env("DSM_HTTP_ADDR", "127.0.0.1:18090"),
	]
	for raw in candidates:
		var normalized := _normalize_ds_manager_base_url(String(raw))
		if not normalized.is_empty():
			LogNetScript.info("ds_manager url resolved: %s" % normalized, "", 0, "net.battle_ds_bootstrap")
			return normalized
	LogNetScript.warn("ds_manager url missing; ready/active control reports disabled", "", 0, "net.battle_ds_bootstrap")
	return ""


func _resolve_ds_manager_auth() -> Dictionary:
	var shared_secret_config: Dictionary = InternalServiceAuthConfigScript.resolve_shared_secret("DSM_INTERNAL_AUTH_SHARED_SECRET", "DSM_INTERNAL_SHARED_SECRET")
	var shared_secret := String(shared_secret_config.get("shared_secret", ""))
	if shared_secret.is_empty():
		var game_auth_secret_config: Dictionary = InternalServiceAuthConfigScript.resolve_shared_secret("GAME_INTERNAL_AUTH_SHARED_SECRET", "GAME_INTERNAL_SHARED_SECRET")
		shared_secret = String(game_auth_secret_config.get("shared_secret", ""))
	var key_id := _read_env("DSM_INTERNAL_AUTH_KEY_ID", "")
	if key_id.is_empty():
		key_id = InternalServiceAuthConfigScript.resolve_key_id("GAME_INTERNAL_AUTH_KEY_ID", "primary")
	return {
		"shared_secret": shared_secret,
		"key_id": key_id,
	}


func _build_ds_manager_auth_signer():
	var auth := _resolve_ds_manager_auth()
	var shared_secret := String(auth.get("shared_secret", ""))
	if shared_secret.is_empty():
		LogNetScript.warn("dsm internal auth secret missing; ready/active control reports disabled", "", 0, "net.battle_ds_bootstrap")
		return null
	var key_id := String(auth.get("key_id", "primary"))
	var signer := InternalAuthSignerScript.new()
	signer.configure(key_id, shared_secret)
	return signer


func _build_ds_manager_http_client(base_url: String):
	if base_url.strip_edges().is_empty():
		return null
	var auth := _resolve_ds_manager_auth()
	var shared_secret := String(auth.get("shared_secret", ""))
	if shared_secret.is_empty():
		return null
	var key_id := String(auth.get("key_id", "primary"))
	var client := InternalJsonServiceClientScript.new()
	client.configure(base_url, key_id, shared_secret, "net.battle_ds_bootstrap")
	return client


func _read_env(env_name: String, fallback: String) -> String:
	var value := OS.get_environment(env_name).strip_edges()
	return value if not value.is_empty() else fallback


func _normalize_game_service_base_url(raw_url: String) -> String:
	return ServiceUrlBuilderScript.normalize_service_base_url(raw_url, 18081, "QQT_GAME_SERVICE_SCHEME")


func _normalize_ds_manager_base_url(raw_url: String) -> String:
	return ServiceUrlBuilderScript.normalize_service_base_url(raw_url, 18090, "QQT_DSM_SERVICE_SCHEME")


func _is_production_env() -> bool:
	for env_name in ["QQT_RUNTIME_ENV", "QQT_ENV", "DSM_ENV", "ROOM_ENV"]:
		var value := OS.get_environment(String(env_name)).strip_edges().to_lower()
		if value == "prod" or value == "production":
			return true
	return false


func _is_unsafe_dev_secret(value: String) -> bool:
	var normalized := value.strip_edges().to_lower()
	if normalized.is_empty():
		return true
	for pattern in ["dev_", "replace_me", "changeme", "qqtang_dev_pass"]:
		if normalized.contains(String(pattern)):
			return true
	return false
