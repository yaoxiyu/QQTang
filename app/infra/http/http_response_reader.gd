class_name HttpResponseReader
extends RefCounted

const LogFrontScript = preload("res://app/logging/log_front.gd")
const LogNetScript = preload("res://app/logging/log_net.gd")
const HTTP_LOG_PREFIX := "[HTTP]"
const DEFAULT_POLL_DELAY_MSEC := 10


static func read_body_bytes(
	client: HTTPClient,
	log_scope: String = "",
	log_tag: String = "",
	source: String = "http_response_reader",
	context: Dictionary = {}
) -> PackedByteArray:
	var chunks := PackedByteArray()
	if client == null:
		_warn(log_scope, log_tag, source, "client_missing", context)
		return chunks
	while true:
		var status := client.get_status()
		match status:
			HTTPClient.STATUS_BODY:
				var raw := client.read_response_body_chunk()
				if not raw.is_empty():
					chunks.append_array(raw)
				client.poll()
				OS.delay_msec(DEFAULT_POLL_DELAY_MSEC)
			HTTPClient.STATUS_REQUESTING, HTTPClient.STATUS_CONNECTING, HTTPClient.STATUS_RESOLVING:
				client.poll()
				OS.delay_msec(DEFAULT_POLL_DELAY_MSEC)
			HTTPClient.STATUS_CONNECTED, HTTPClient.STATUS_DISCONNECTED:
				return chunks
			HTTPClient.STATUS_CONNECTION_ERROR, HTTPClient.STATUS_CANT_CONNECT, HTTPClient.STATUS_CANT_RESOLVE, HTTPClient.STATUS_TLS_HANDSHAKE_ERROR:
				var payload := context.duplicate(true)
				payload["status"] = _status_name(status)
				payload["response_code"] = client.get_response_code()
				_warn(log_scope, log_tag, source, "transport_terminal_status", payload)
				return chunks
			_:
				var payload := context.duplicate(true)
				payload["status"] = _status_name(status)
				payload["response_code"] = client.get_response_code()
				_warn(log_scope, log_tag, source, "transport_unexpected_status", payload)
				return chunks
	return chunks


static func _warn(log_scope: String, log_tag: String, source: String, event_name: String, payload: Dictionary) -> void:
	var message := "%s[%s] %s %s" % [HTTP_LOG_PREFIX, source, event_name, JSON.stringify(payload)]
	match log_scope:
		"front":
			LogFrontScript.warn(message, "", 0, log_tag)
		"net":
			LogNetScript.warn(message, "", 0, log_tag)
		_:
			pass


static func _status_name(status: int) -> String:
	match status:
		HTTPClient.STATUS_DISCONNECTED:
			return "DISCONNECTED"
		HTTPClient.STATUS_RESOLVING:
			return "RESOLVING"
		HTTPClient.STATUS_CANT_RESOLVE:
			return "CANT_RESOLVE"
		HTTPClient.STATUS_CONNECTING:
			return "CONNECTING"
		HTTPClient.STATUS_CANT_CONNECT:
			return "CANT_CONNECT"
		HTTPClient.STATUS_CONNECTED:
			return "CONNECTED"
		HTTPClient.STATUS_REQUESTING:
			return "REQUESTING"
		HTTPClient.STATUS_BODY:
			return "BODY"
		HTTPClient.STATUS_CONNECTION_ERROR:
			return "CONNECTION_ERROR"
		HTTPClient.STATUS_TLS_HANDSHAKE_ERROR:
			return "TLS_HANDSHAKE_ERROR"
		_:
			return "UNKNOWN_%d" % status
