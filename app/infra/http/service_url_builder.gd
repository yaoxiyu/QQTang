class_name ServiceUrlBuilder
extends RefCounted

const HttpUrlParserScript = preload("res://app/infra/http/http_url_parser.gd")


static func build_account_base_url(host_input: String, port_input: int, default_port: int = 18080) -> String:
	return build_service_base_url(host_input, port_input, default_port, "QQT_ACCOUNT_SERVICE_SCHEME")


static func build_game_base_url(host_input: String, port_input: int, default_port: int = 18081) -> String:
	return build_service_base_url(host_input, port_input, default_port, "QQT_GAME_SERVICE_SCHEME")


static func build_ds_manager_base_url(host_input: String, port_input: int, default_port: int = 18090) -> String:
	return build_service_base_url(host_input, port_input, default_port, "QQT_DSM_SERVICE_SCHEME")


static func normalize_service_base_url(raw_input: String, default_port: int, scheme_env_name: String) -> String:
	var value := raw_input.strip_edges().trim_suffix("/")
	if value.is_empty():
		return ""
	if value.begins_with(":"):
		value = "127.0.0.1" + value
	return build_service_base_url(value, default_port, default_port, scheme_env_name)


static func parse_host_and_explicit_port(base_url: String) -> Dictionary:
	var trimmed := base_url.strip_edges()
	if trimmed.is_empty():
		return {}
	var parsed := HttpUrlParserScript.parse(trimmed)
	if parsed.is_empty():
		return {}
	var authority := _extract_authority(trimmed)
	var explicit_port := _extract_explicit_port(authority)
	return {
		"host": String(parsed.get("host", "")).strip_edges(),
		"port": explicit_port,
	}


static func build_service_base_url(host_input: String, port_input: int, default_port: int, scheme_env_name: String) -> String:
	var host := host_input.strip_edges()
	if host.is_empty():
		host = "127.0.0.1"
	var scheme := _resolve_scheme(scheme_env_name)
	if host.begins_with("http://") or host.begins_with("https://"):
		return _normalize_absolute_url(host, default_port, scheme)
	if host.begins_with(":"):
		host = "127.0.0.1" + host
	if host.find(":") > 0:
		return "%s://%s" % [scheme, host]
	var port := port_input if port_input > 0 else default_port
	return "%s://%s:%d" % [scheme, host, port]


static func _normalize_absolute_url(url: String, fallback_port: int, fallback_scheme: String) -> String:
	var parsed := HttpUrlParserScript.parse(url)
	if parsed.is_empty():
		return ""
	var scheme := "https" if bool(parsed.get("use_tls", false)) else fallback_scheme
	var host := String(parsed.get("host", "")).strip_edges()
	var port := int(parsed.get("port", 0))
	var explicit_port := _extract_explicit_port(_extract_authority(url))
	if host.is_empty():
		return ""
	if explicit_port > 0:
		port = explicit_port
	elif port <= 0:
		port = fallback_port
	else:
		port = fallback_port
	return "%s://%s:%d" % [scheme, host, port]


static func _resolve_scheme(env_name: String) -> String:
	var value := OS.get_environment(env_name).strip_edges().to_lower()
	var scheme := "https" if value == "https" else "http"
	if _is_https_required():
		return "https"
	return scheme


static func _is_https_required() -> bool:
	var value := OS.get_environment("QQT_REQUIRE_HTTPS").strip_edges().to_lower()
	return value == "1" or value == "true" or value == "yes" or value == "on"


static func _extract_authority(url: String) -> String:
	var normalized := url.strip_edges()
	var scheme_split := normalized.split("://", false, 1)
	if scheme_split.size() != 2:
		return ""
	var without_scheme := String(scheme_split[1])
	var slash_index := without_scheme.find("/")
	if slash_index >= 0:
		return without_scheme.substr(0, slash_index)
	return without_scheme


static func _extract_explicit_port(authority: String) -> int:
	var normalized := authority.strip_edges()
	if normalized.is_empty():
		return 0
	var colon_index := normalized.rfind(":")
	if colon_index <= 0 or colon_index >= normalized.length() - 1:
		return 0
	var port := int(normalized.substr(colon_index + 1).to_int())
	return port if port > 0 else 0
