class_name GameServicePartyQueueResult
extends RefCounted


static func ok(data: Dictionary = {}) -> Dictionary:
	var result := data.duplicate(true)
	result["ok"] = true
	if not result.has("error_code"):
		result["error_code"] = ""
	if not result.has("user_message"):
		result["user_message"] = ""
	return result


static func fail(error_code: String, user_message: String, details: Dictionary = {}) -> Dictionary:
	return {
		"ok": false,
		"error_code": error_code,
		"user_message": user_message,
		"details": details.duplicate(true),
	}


static func normalize(value: Variant) -> Dictionary:
	if not value is Dictionary:
		return fail("PARTY_QUEUE_RESPONSE_INVALID", "Party queue service returned invalid response")
	var result: Dictionary = (value as Dictionary).duplicate(true)
	if not result.has("ok"):
		result["ok"] = result.get("error_code", "") == ""
	if not result.has("error_code"):
		result["error_code"] = ""
	if not result.has("user_message") and result.has("message"):
		result["user_message"] = String(result.get("message", ""))
	if not result.has("user_message"):
		result["user_message"] = ""
	return result
