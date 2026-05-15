class_name HttpUrlParser
extends RefCounted


static func parse(url: String) -> Dictionary:
	var normalized := url.strip_edges()
	var use_tls := false
	if normalized.begins_with("https://"):
		use_tls = true
	elif normalized.begins_with("http://"):
		use_tls = false
	else:
		return {}
	if _is_https_required() and not use_tls:
		return {}
	var scheme_len := 8 if use_tls else 7
	var without_scheme := normalized.substr(scheme_len)
	var slash_index := without_scheme.find("/")
	var host_port := without_scheme
	var path := "/"
	if slash_index >= 0:
		host_port = without_scheme.substr(0, slash_index)
		path = without_scheme.substr(slash_index, without_scheme.length() - slash_index)
	if host_port.is_empty():
		return {}
	var colon_index := host_port.rfind(":")
	var host := host_port
	var port := 443 if use_tls else 80
	if colon_index > 0 and colon_index < host_port.length() - 1:
		host = host_port.substr(0, colon_index)
		port = int(host_port.substr(colon_index + 1, host_port.length() - colon_index - 1))
		if port <= 0:
			return {}
	if host.strip_edges().is_empty():
		return {}
	return {
		"host": host,
		"port": port,
		"path": path,
		"use_tls": use_tls,
	}


static func _is_https_required() -> bool:
	if _is_insecure_http_allowed():
		return false
	var value := OS.get_environment("QQT_REQUIRE_HTTPS").strip_edges().to_lower()
	if value == "0" or value == "false" or value == "no" or value == "off":
		return false
	if value == "1" or value == "true" or value == "yes" or value == "on":
		return true
	# Secure-by-default: require HTTPS unless explicitly relaxed for local dev.
	return true


static func _is_insecure_http_allowed() -> bool:
	var value := OS.get_environment("QQT_ALLOW_INSECURE_HTTP").strip_edges().to_lower()
	return value == "1" or value == "true" or value == "yes" or value == "on"
