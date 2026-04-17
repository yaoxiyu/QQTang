class_name HttpResponse
extends RefCounted

var ok: bool = false
var status_code: int = 0
var headers: PackedStringArray = PackedStringArray()
var body_text: String = ""
var body_json: Variant = null
var transport_error: int = OK
var error_code: String = ""
var error_message: String = ""


static func from_error(p_error_code: String, p_error_message: String, p_transport_error: int = ERR_CANT_CONNECT) -> HttpResponse:
	var response := HttpResponse.new()
	response.ok = false
	response.error_code = p_error_code
	response.error_message = p_error_message
	response.transport_error = p_transport_error
	return response
