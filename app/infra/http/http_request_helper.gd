class_name HttpRequestHelper
extends RefCounted

const HttpUrlParserScript = preload("res://app/infra/http/http_url_parser.gd")

static func parse_url(url: String) -> Dictionary:
	return HttpUrlParserScript.parse(url)
