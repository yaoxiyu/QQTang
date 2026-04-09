class_name SessionLifecycleState
extends RefCounted

enum Value {
	NONE,
	CREATING_ROOM,
	ROOM_ACTIVE,
	MATCH_NEGOTIATING,
	MATCH_LOADING,
	MATCH_ACTIVE,
	MATCH_ENDING,
	RECOVERING_ROOM,
	DISPOSING,
	DISPOSED,
	ERROR,
}


static func state_to_string(state: int) -> String:
	match state:
		Value.NONE:
			return "NONE"
		Value.CREATING_ROOM:
			return "CREATING_ROOM"
		Value.ROOM_ACTIVE:
			return "ROOM_ACTIVE"
		Value.MATCH_NEGOTIATING:
			return "MATCH_NEGOTIATING"
		Value.MATCH_LOADING:
			return "MATCH_LOADING"
		Value.MATCH_ACTIVE:
			return "MATCH_ACTIVE"
		Value.MATCH_ENDING:
			return "MATCH_ENDING"
		Value.RECOVERING_ROOM:
			return "RECOVERING_ROOM"
		Value.DISPOSING:
			return "DISPOSING"
		Value.DISPOSED:
			return "DISPOSED"
		Value.ERROR:
			return "ERROR"
		_:
			return "UNKNOWN"

