class_name RegisterRequest
extends RefCounted

var account: String = ""
var password: String = ""
var nickname: String = ""
var client_platform: String = ""
var server_host: String = ""
var server_port: int = 0


func to_dict() -> Dictionary:
	return {
		"account": account,
		"password": password,
		"nickname": nickname,
		"client_platform": client_platform,
		"server_host": server_host,
		"server_port": server_port,
	}
