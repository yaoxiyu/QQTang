extends RefCounted

const AppRuntimeServicesScript = preload("res://app/flow/app_runtime_services.gd")


static func ensure_all(runtime: Node) -> void:
	if runtime == null:
		return
	ensure_foundation(runtime)
	ensure_front_use_cases(runtime)


static func ensure_foundation(runtime: Node) -> void:
	if runtime == null:
		return
	AppRuntimeServicesScript.ensure_runtime_contexts(runtime)
	AppRuntimeServicesScript.ensure_runtime_config(runtime)
	AppRuntimeServicesScript.ensure_front_repositories(runtime)
	AppRuntimeServicesScript.ensure_front_local_state(runtime)
	AppRuntimeServicesScript.ensure_front_services(runtime)


static func ensure_front_use_cases(runtime: Node) -> void:
	if runtime == null:
		return
	AppRuntimeServicesScript.ensure_front_use_cases(runtime)
