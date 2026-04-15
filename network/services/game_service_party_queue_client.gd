class_name GameServicePartyQueueClient
extends RefCounted

const HttpResponseReaderScript = preload("res://app/http/http_response_reader.gd")
const ResultScript = preload("res://network/services/game_service_party_queue_result.gd")

const ENTER_PATH := "/internal/v1/matchmaking/party-queue/enter"
const CANCEL_PATH := "/internal/v1/matchmaking/party-queue/cancel"
const STATUS_PATH := "/internal/v1/matchmaking/party-queue/status"

var base_url: String = ""
var service_token: String = ""


func configure(p_base_url: String, p_service_token: String) -> void:
	base_url = p_base_url.strip_edges().trim_suffix("/")
	service_token = p_service_token.strip_edges()


func enter_party_queue(request: Dictionary) -> Dictionary:
	return _send_json_request(HTTPClient.METHOD_POST, ENTER_PATH, request)


func cancel_party_queue(party_room_id: String, queue_entry_id: String) -> Dictionary:
	return _send_json_request(HTTPClient.METHOD_POST, CANCEL_PATH, {
		"party_room_id": party_room_id,
		"queue_entry_id": queue_entry_id,
	})


func get_party_queue_status(party_room_id: String, queue_entry_id: String) -> Dictionary:
	var query := "?party_room_id=%s&queue_entry_id=%s" % [
		party_room_id.uri_encode(),
		queue_entry_id.uri_encode(),
	]
	return _send_json_request(HTTPClient.METHOD_GET, STATUS_PATH + query, null)


func _send_json_request(method: int, path: String, payload: Variant) -> Dictionary:
	if base_url.is_empty():
		return ResultScript.fail("PARTY_QUEUE_URL_MISSING", "Game service party queue url is missing")
	if service_token.is_empty():
		return ResultScript.fail("PARTY_QUEUE_SERVICE_TOKEN_MISSING", "Game service party queue token is missing")
	var parsed_url := _parse_url(base_url + path)
	if parsed_url.is_empty():
		return ResultScript.fail("PARTY_QUEUE_URL_INVALID", "Game service party queue url is invalid")

	var client := HTTPClient.new()
	var err := client.connect_to_host(String(parsed_url["host"]), int(parsed_url["port"]))
	if err != OK:
		return ResultScript.fail("PARTY_QUEUE_CONNECT_FAILED", "Failed to connect game service")
	while client.get_status() == HTTPClient.STATUS_CONNECTING or client.get_status() == HTTPClient.STATUS_RESOLVING:
		client.poll()
		OS.delay_msec(10)
	if client.get_status() != HTTPClient.STATUS_CONNECTED:
		return ResultScript.fail("PARTY_QUEUE_CONNECT_FAILED", "Failed to connect game service")

	var headers := PackedStringArray([
		"Content-Type: application/json",
		"X-Internal-Secret: %s" % service_token,
	])
	var body := "" if payload == null else JSON.stringify(payload)
	err = client.request(method, String(parsed_url["path"]), headers, body)
	if err != OK:
		return ResultScript.fail("PARTY_QUEUE_REQUEST_FAILED", "Failed to send party queue request")

	while client.get_status() == HTTPClient.STATUS_REQUESTING:
		client.poll()
		OS.delay_msec(10)

	var chunks := HttpResponseReaderScript.read_body_bytes(
		client,
		"net",
		"net.party_queue",
		"game_service_party_queue_client",
		{
			"path": path,
			"method": method,
		}
	)
	var text := chunks.get_string_from_utf8()
	if text.strip_edges().is_empty():
		return ResultScript.fail("PARTY_QUEUE_EMPTY_RESPONSE", "Game service returned empty party queue response")
	var json := JSON.new()
	if json.parse(text) != OK:
		return ResultScript.fail("PARTY_QUEUE_RESPONSE_INVALID", "Game service returned invalid party queue response")
	return ResultScript.normalize(json.data)


func _parse_url(url: String) -> Dictionary:
	var normalized := url.strip_edges()
	if not normalized.begins_with("http://"):
		return {}
	var without_scheme := normalized.substr(7)
	var slash_index := without_scheme.find("/")
	var host_port := without_scheme
	var path := "/"
	if slash_index >= 0:
		host_port = without_scheme.substr(0, slash_index)
		path = without_scheme.substr(slash_index, without_scheme.length() - slash_index)
	var colon_index := host_port.rfind(":")
	if colon_index <= 0 or colon_index >= host_port.length() - 1:
		return {}
	return {
		"host": host_port.substr(0, colon_index),
		"port": int(host_port.substr(colon_index + 1, host_port.length() - colon_index - 1)),
		"path": path,
	}
