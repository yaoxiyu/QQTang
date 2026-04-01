class_name BattleFlowState
extends RefCounted

enum Value {
	NONE,
	LOADING_SCENE,
	BOOTSTRAPPING,
	WAITING_START,
	RUNNING,
	FINISHING,
	FINISHED,
	EXITING,
	ERROR,
}


static func state_to_string(state: int) -> String:
	match state:
		Value.NONE:
			return "NONE"
		Value.LOADING_SCENE:
			return "LOADING_SCENE"
		Value.BOOTSTRAPPING:
			return "BOOTSTRAPPING"
		Value.WAITING_START:
			return "WAITING_START"
		Value.RUNNING:
			return "RUNNING"
		Value.FINISHING:
			return "FINISHING"
		Value.FINISHED:
			return "FINISHED"
		Value.EXITING:
			return "EXITING"
		Value.ERROR:
			return "ERROR"
		_:
			return "UNKNOWN"
