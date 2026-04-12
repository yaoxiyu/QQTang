class_name LoginRequest
extends RefCounted

var nickname: String = ""
var account: String = ""
var password: String = ""
var client_platform: String = ""
var profile_id: String = ""
var default_character_id: String = ""
var default_character_skin_id: String = ""
var default_bubble_style_id: String = ""
var default_bubble_skin_id: String = ""
var server_host: String = ""
var server_port: int = 0


func to_dict() -> Dictionary:
	return {
		"nickname": nickname,
		"account": account,
		"password": password,
		"client_platform": client_platform,
		"profile_id": profile_id,
		"default_character_id": default_character_id,
		"default_character_skin_id": default_character_skin_id,
		"default_bubble_style_id": default_bubble_style_id,
		"default_bubble_skin_id": default_bubble_skin_id,
		"server_host": server_host,
		"server_port": server_port,
	}
