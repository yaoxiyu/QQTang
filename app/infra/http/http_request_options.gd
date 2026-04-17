class_name HttpRequestOptions
extends RefCounted

var method: int = HTTPClient.METHOD_GET
var url: String = ""
var headers: PackedStringArray = PackedStringArray()
var body_text: String = ""
var connect_timeout_ms: int = 5000
var read_timeout_ms: int = 8000
var parse_json: bool = true
var log_tag: String = "http.request"
