class_name HttpRoomTicketGateway
extends "res://app/front/auth/room_ticket_gateway.gd"

const HttpRoomTicketResultScript = preload("res://app/front/auth/room_ticket_result.gd")

var service_base_url: String = ""


func configure_base_url(base_url: String) -> void:
	service_base_url = base_url.strip_edges()


func issue_room_ticket(access_token: String, request):
	if request == null:
		return HttpRoomTicketResultScript.fail("ROOM_TICKET_REQUEST_INVALID", "Room ticket request is missing")
	if service_base_url.is_empty():
		return HttpRoomTicketResultScript.fail("ROOM_TICKET_URL_MISSING", "Room ticket service url is missing")
	var client := HTTPClient.new()
	var parsed_url := _parse_url(service_base_url + "/api/v1/tickets/room-entry")
	if parsed_url.is_empty():
		return HttpRoomTicketResultScript.fail("ROOM_TICKET_URL_INVALID", "Room ticket service url is invalid")
	var err := client.connect_to_host(String(parsed_url["host"]), int(parsed_url["port"]))
	if err != OK:
		return HttpRoomTicketResultScript.fail("ROOM_TICKET_CONNECT_FAILED", "Failed to connect room ticket service")
	while client.get_status() == HTTPClient.STATUS_CONNECTING or client.get_status() == HTTPClient.STATUS_RESOLVING:
		client.poll()
		OS.delay_msec(10)
	if client.get_status() != HTTPClient.STATUS_CONNECTED:
		return HttpRoomTicketResultScript.fail("ROOM_TICKET_CONNECT_FAILED", "Failed to connect room ticket service")
	var headers := PackedStringArray([
		"Content-Type: application/json",
		"Authorization: Bearer %s" % access_token,
	])
	err = client.request(HTTPClient.METHOD_POST, String(parsed_url["path"]), headers, JSON.stringify(request.to_dict()))
	if err != OK:
		return HttpRoomTicketResultScript.fail("ROOM_TICKET_REQUEST_FAILED", "Failed to send room ticket request")
	while client.get_status() == HTTPClient.STATUS_REQUESTING:
		client.poll()
		OS.delay_msec(10)
	var raw := client.read_response_body_chunk()
	var chunks := PackedByteArray()
	while client.get_status() == HTTPClient.STATUS_BODY or not raw.is_empty():
		chunks.append_array(raw)
		client.poll()
		raw = client.read_response_body_chunk()
	var text := chunks.get_string_from_utf8()
	if text.strip_edges().is_empty():
		return HttpRoomTicketResultScript.fail("ROOM_TICKET_EMPTY_RESPONSE", "Room ticket service returned empty response")
	var json := JSON.new()
	if json.parse(text) != OK or not (json.data is Dictionary):
		return HttpRoomTicketResultScript.fail("ROOM_TICKET_RESPONSE_INVALID", "Room ticket service returned invalid response")
	var response: Dictionary = json.data
	if not bool(response.get("ok", false)):
		return HttpRoomTicketResultScript.fail(String(response.get("error_code", "ROOM_TICKET_REQUEST_FAILED")), String(response.get("user_message", response.get("message", "Room ticket request failed"))))
	return HttpRoomTicketResultScript.success_from_dict(response)


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
