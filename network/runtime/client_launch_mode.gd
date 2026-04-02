class_name ClientLaunchMode
extends RefCounted

enum Value {
	LOCAL_SINGLEPLAYER,
	NETWORK_CLIENT,
	TRANSPORT_DEBUG,
}


static func mode_to_string(mode: int) -> String:
	match mode:
		Value.LOCAL_SINGLEPLAYER:
			return "LOCAL_SINGLEPLAYER"
		Value.NETWORK_CLIENT:
			return "NETWORK_CLIENT"
		Value.TRANSPORT_DEBUG:
			return "TRANSPORT_DEBUG"
		_:
			return "UNKNOWN"


static func is_formal_client_mode(mode: int) -> bool:
	return mode == Value.LOCAL_SINGLEPLAYER or mode == Value.NETWORK_CLIENT
