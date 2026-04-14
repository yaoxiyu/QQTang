class_name ResumeTokenUtils
extends RefCounted

const TOKEN_RANDOM_BYTES: int = 32


static func generate_resume_token() -> String:
	var crypto := Crypto.new()
	var bytes := crypto.generate_random_bytes(TOKEN_RANDOM_BYTES)
	return _to_base64_url(bytes)


static func hash_resume_token(token: String) -> String:
	var normalized := token.strip_edges()
	if normalized.is_empty():
		return ""
	var hashing := HashingContext.new()
	var err := hashing.start(HashingContext.HASH_SHA256)
	if err != OK:
		return ""
	hashing.update(normalized.to_utf8_buffer())
	return hashing.finish().hex_encode()


static func _to_base64_url(bytes: PackedByteArray) -> String:
	return Marshalls.raw_to_base64(bytes).replace("+", "-").replace("/", "_").trim_suffix("=")
