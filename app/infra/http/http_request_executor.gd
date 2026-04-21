class_name HttpRequestExecutor
extends RefCounted

const HttpResponseScript = preload("res://app/infra/http/http_response.gd")
const HttpRequestHelperScript = preload("res://app/infra/http/http_request_helper.gd")
const HttpResponseReaderScript = preload("res://app/infra/http/http_response_reader.gd")


static func execute(options: HttpRequestOptions) -> HttpResponse:
	if options == null or options.url.strip_edges().is_empty():
		return HttpResponseScript.from_error("HTTP_URL_MISSING", "HTTP request url is missing", ERR_INVALID_PARAMETER)
	var parsed_url := HttpRequestHelperScript.parse_url(options.url)
	if parsed_url.is_empty():
		return HttpResponseScript.from_error("HTTP_URL_INVALID", "HTTP request url is invalid", ERR_INVALID_PARAMETER)

	var client := HTTPClient.new()
	var connect_err := client.connect_to_host(String(parsed_url.get("host", "")), int(parsed_url.get("port", 0)))
	if connect_err != OK:
		return HttpResponseScript.from_error("HTTP_CONNECT_FAILED", "Failed to connect host", connect_err)
	if not _wait_for_status(client, [HTTPClient.STATUS_CONNECTED], options.connect_timeout_ms):
		return HttpResponseScript.from_error("HTTP_CONNECT_TIMEOUT", "HTTP connect timeout", ERR_TIMEOUT)
	if client.get_status() != HTTPClient.STATUS_CONNECTED:
		return HttpResponseScript.from_error("HTTP_CONNECT_FAILED", "Failed to connect host", ERR_CANT_CONNECT)

	var request_err := client.request(options.method, String(parsed_url.get("path", "/")), options.headers, options.body_text)
	if request_err != OK:
		return HttpResponseScript.from_error("HTTP_REQUEST_FAILED", "Failed to send request", request_err)
	if not _wait_for_request_ready(client, options.read_timeout_ms):
		return HttpResponseScript.from_error("HTTP_REQUEST_TIMEOUT", "HTTP request timeout", ERR_TIMEOUT)

	var response := HttpResponseScript.new()
	response.status_code = int(client.get_response_code())
	response.headers = client.get_response_headers()
	var chunks := HttpResponseReaderScript.read_body_bytes(
		client,
		"infra",
		options.log_tag,
		"http_request_executor",
		{
			"url": options.url,
			"method": options.method,
			"status_code": response.status_code,
		}
	)
	response.body_text = chunks.get_string_from_utf8()
	if options.parse_json and not response.body_text.strip_edges().is_empty():
		var json := JSON.new()
		if json.parse(response.body_text) == OK:
			response.body_json = json.data
		else:
			response.error_code = "HTTP_RESPONSE_JSON_INVALID"
			response.error_message = "HTTP response json parse failed"
			response.transport_error = ERR_PARSE_ERROR
			response.ok = false
			return response

	response.ok = response.status_code >= 200 and response.status_code < 300
	return response


static func _wait_for_status(client: HTTPClient, accept_statuses: Array[int], timeout_ms: int) -> bool:
	var deadline_ms : int = Time.get_ticks_msec() + max(timeout_ms, 1)
	while client.get_status() == HTTPClient.STATUS_CONNECTING or client.get_status() == HTTPClient.STATUS_RESOLVING:
		if Time.get_ticks_msec() > deadline_ms:
			return false
		client.poll()
		OS.delay_msec(10)
	return accept_statuses.has(client.get_status())


static func _wait_for_request_ready(client: HTTPClient, timeout_ms: int) -> bool:
	var deadline_ms : int = Time.get_ticks_msec() + max(timeout_ms, 1)
	while client.get_status() == HTTPClient.STATUS_REQUESTING:
		if Time.get_ticks_msec() > deadline_ms:
			return false
		client.poll()
		OS.delay_msec(10)
	return true
