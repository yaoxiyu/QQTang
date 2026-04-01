class_name RoomFlowState
extends RefCounted

enum Value {
	NONE,
	ENTERING,
	IDLE,
	HOSTING,
	JOINING,
	IN_ROOM,
	PREPARING_MATCH,
	STARTING_MATCH,
	IN_BATTLE,
	RETURNING_FROM_BATTLE,
	ERROR,
}


static func state_to_string(state: int) -> String:
	match state:
		Value.NONE:
			return "NONE"
		Value.ENTERING:
			return "ENTERING"
		Value.IDLE:
			return "IDLE"
		Value.HOSTING:
			return "HOSTING"
		Value.JOINING:
			return "JOINING"
		Value.IN_ROOM:
			return "IN_ROOM"
		Value.PREPARING_MATCH:
			return "PREPARING_MATCH"
		Value.STARTING_MATCH:
			return "STARTING_MATCH"
		Value.IN_BATTLE:
			return "IN_BATTLE"
		Value.RETURNING_FROM_BATTLE:
			return "RETURNING_FROM_BATTLE"
		Value.ERROR:
			return "ERROR"
		_:
			return "UNKNOWN"

