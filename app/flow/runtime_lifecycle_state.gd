class_name RuntimeLifecycleState
extends RefCounted

enum Value {
	NONE,
	ATTACH_PENDING,
	INITIALIZING,
	READY,
	DISPOSING,
	DISPOSED,
	ERROR,
}


static func state_to_string(state: int) -> String:
	match state:
		Value.NONE:
			return "NONE"
		Value.ATTACH_PENDING:
			return "ATTACH_PENDING"
		Value.INITIALIZING:
			return "INITIALIZING"
		Value.READY:
			return "READY"
		Value.DISPOSING:
			return "DISPOSING"
		Value.DISPOSED:
			return "DISPOSED"
		Value.ERROR:
			return "ERROR"
		_:
			return "UNKNOWN"
