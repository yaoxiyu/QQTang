class_name HttpRequestHelper
extends RefCounted

const HttpUrlParserScript = preload("res://app/infra/http/http_url_parser.gd")
const HttpRequestExecutorScript = preload("res://app/infra/http/http_request_executor.gd")

static func parse_url(url: String) -> Dictionary:
	return HttpUrlParserScript.parse(url)


static func execute(options: HttpRequestOptions) -> HttpResponse:
	return await HttpRequestExecutorScript.execute_async(options)


static func execute_async(options: HttpRequestOptions) -> HttpResponse:
	return await HttpRequestExecutorScript.execute_async(options)
