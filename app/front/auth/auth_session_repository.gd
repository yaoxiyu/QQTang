class_name AuthSessionRepository
extends RefCounted


func load_session() -> AuthSessionState:
	return AuthSessionState.new()


func save_session(state: AuthSessionState) -> bool:
	return false


func clear_session() -> void:
	pass
