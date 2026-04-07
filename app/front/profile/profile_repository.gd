class_name ProfileRepository
extends RefCounted


func load_profile() -> PlayerProfileState:
	return PlayerProfileState.new()


func save_profile(profile: PlayerProfileState) -> bool:
	return profile != null
