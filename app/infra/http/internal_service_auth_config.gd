class_name InternalServiceAuthConfig
extends RefCounted


static func read_env(name: String, fallback: String = "") -> String:
	var value := OS.get_environment(name).strip_edges()
	return value if not value.is_empty() else fallback


static func resolve_key_id(key_id_env: String, fallback: String = "primary") -> String:
	var resolved := read_env(key_id_env, fallback).strip_edges()
	return resolved if not resolved.is_empty() else fallback


static func resolve_shared_secret(primary_env: String, legacy_env: String = "") -> Dictionary:
	var secret := read_env(primary_env, "")
	if not secret.is_empty():
		return {
			"shared_secret": secret,
			"source_env": primary_env,
			"used_legacy_fallback": false,
		}
	if legacy_env.strip_edges().is_empty():
		return {
			"shared_secret": "",
			"source_env": "",
			"used_legacy_fallback": false,
		}
	secret = read_env(legacy_env, "")
	return {
		"shared_secret": secret,
		"source_env": legacy_env if not secret.is_empty() else "",
		"used_legacy_fallback": not secret.is_empty(),
	}
