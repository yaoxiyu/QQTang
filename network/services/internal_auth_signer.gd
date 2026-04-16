class_name InternalAuthSigner
extends RefCounted

## HMAC-SHA256 request signer compatible with game_service internal auth.
## Canonical string: METHOD\nPATH_AND_QUERY\nTIMESTAMP\nNONCE\nBODY_HASH

const HEADER_KEY_ID := "X-Internal-Key-Id"
const HEADER_TIMESTAMP := "X-Internal-Timestamp"
const HEADER_NONCE := "X-Internal-Nonce"
const HEADER_BODY_SHA256 := "X-Internal-Body-SHA256"
const HEADER_SIGNATURE := "X-Internal-Signature"

var key_id: String = "primary"
var shared_secret: String = ""


func configure(p_key_id: String, p_shared_secret: String) -> void:
	key_id = p_key_id.strip_edges() if not p_key_id.strip_edges().is_empty() else "primary"
	shared_secret = p_shared_secret.strip_edges()


func sign_headers(method: String, path_and_query: String, body: String) -> PackedStringArray:
	var timestamp := str(int(Time.get_unix_time_from_system()))
	var nonce := _generate_nonce()
	var body_hash := _sha256_hex(body.to_utf8_buffer())
	var canonical := "%s\n%s\n%s\n%s\n%s" % [method, path_and_query, timestamp, nonce, body_hash]
	var signature := _hmac_sha256_hex(shared_secret.to_utf8_buffer(), canonical.to_utf8_buffer())
	return PackedStringArray([
		"Content-Type: application/json",
		"%s: %s" % [HEADER_KEY_ID, key_id],
		"%s: %s" % [HEADER_TIMESTAMP, timestamp],
		"%s: %s" % [HEADER_NONCE, nonce],
		"%s: %s" % [HEADER_BODY_SHA256, body_hash],
		"%s: %s" % [HEADER_SIGNATURE, signature],
	])


func _generate_nonce() -> String:
	var crypto := Crypto.new()
	return crypto.generate_random_bytes(16).hex_encode()


func _sha256_hex(data: PackedByteArray) -> String:
	if data.is_empty():
		# SHA-256 of empty input — HashingContext.update rejects empty arrays
		return "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(data)
	return ctx.finish().hex_encode()


func _hmac_sha256_hex(key: PackedByteArray, data: PackedByteArray) -> String:
	var crypto := Crypto.new()
	var digest := crypto.hmac_digest(HashingContext.HASH_SHA256, key, data)
	return digest.hex_encode()
