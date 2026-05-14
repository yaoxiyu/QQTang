class_name HttpRoomTicketGateway
extends "res://app/front/auth/room_ticket_gateway.gd"

const HttpRoomTicketResultScript = preload("res://app/front/auth/room_ticket_result.gd")
const HttpRequestExecutorScript = preload("res://app/infra/http/http_request_executor.gd")
const HttpRequestOptionsScript = preload("res://app/infra/http/http_request_options.gd")

var service_base_url: String = ""


func configure_base_url(base_url: String) -> void:
	service_base_url = base_url.strip_edges()


func issue_room_ticket(access_token: String, request):
	if request == null:
		return HttpRoomTicketResultScript.fail("ROOM_TICKET_REQUEST_INVALID", "Room ticket request is missing")
	if service_base_url.is_empty():
		return HttpRoomTicketResultScript.fail("ROOM_TICKET_URL_MISSING", "Room ticket service url is missing")
	var options := HttpRequestOptionsScript.new()
	options.method = HTTPClient.METHOD_POST
	options.url = service_base_url + "/api/v1/tickets/room-entry"
	options.log_tag = "front.auth.room_ticket_gateway"
	options.headers = PackedStringArray([
		"Content-Type: application/json",
		"Authorization: Bearer %s" % access_token,
	])
	options.body_text = JSON.stringify(request.to_dict())
	var response = await HttpRequestExecutorScript.execute_async(options)
	if response.error_code == "HTTP_URL_INVALID":
		return HttpRoomTicketResultScript.fail("ROOM_TICKET_URL_INVALID", "Room ticket service url is invalid")
	if response.error_code == "HTTP_CONNECT_FAILED" or response.error_code == "HTTP_CONNECT_TIMEOUT":
		return HttpRoomTicketResultScript.fail("ROOM_TICKET_CONNECT_FAILED", "Failed to connect room ticket service")
	if response.error_code == "HTTP_REQUEST_FAILED" or response.error_code == "HTTP_REQUEST_TIMEOUT":
		return HttpRoomTicketResultScript.fail("ROOM_TICKET_REQUEST_FAILED", "Failed to send room ticket request")
	var text := String(response.body_text)
	if text.strip_edges().is_empty():
		return HttpRoomTicketResultScript.fail("ROOM_TICKET_EMPTY_RESPONSE", "Room ticket service returned empty response")
	if not (response.body_json is Dictionary):
		return HttpRoomTicketResultScript.fail("ROOM_TICKET_RESPONSE_INVALID", "Room ticket service returned invalid response")
	var response_body: Dictionary = response.body_json
	if not bool(response_body.get("ok", false)):
		return HttpRoomTicketResultScript.fail(String(response_body.get("error_code", "ROOM_TICKET_REQUEST_FAILED")), String(response_body.get("user_message", response_body.get("message", "Room ticket request failed"))))
	return HttpRoomTicketResultScript.success_from_dict(response_body)
