class_name HttpRoomTicketGateway
extends "res://app/front/auth/room_ticket_gateway.gd"

const HttpRoomTicketResultScript = preload("res://app/front/auth/room_ticket_result.gd")
const HttpResponseReaderScript = preload("res://app/http/http_response_reader.gd")
const HttpRequestHelperScript = preload("res://app/infra/http/http_request_helper.gd")

var service_base_url: String = ""


func configure_base_url(base_url: String) -> void:
	service_base_url = base_url.strip_edges()


func issue_room_ticket(access_token: String, request):
	if request == null:
		return HttpRoomTicketResultScript.fail("ROOM_TICKET_REQUEST_INVALID", "Room ticket request is missing")
	if service_base_url.is_empty():
		return HttpRoomTicketResultScript.fail("ROOM_TICKET_URL_MISSING", "Room ticket service url is missing")
	var client := HTTPClient.new()
	var parsed_url := HttpRequestHelperScript.parse_url(service_base_url + "/api/v1/tickets/room-entry")
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
	var chunks := HttpResponseReaderScript.read_body_bytes(
		client,
		"front",
		"front.auth.room_ticket_gateway",
		"http_room_ticket_gateway",
		{
			"url": service_base_url + "/api/v1/tickets/room-entry",
			"method": HTTPClient.METHOD_POST,
			"room_kind": String(request.room_kind),
			"assignment_id": String(request.assignment_id),
		}
	)
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
