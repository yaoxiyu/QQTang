extends RefCounted

const AppNavigationCoordinatorScript = preload("res://app/flow/app_navigation_coordinator.gd")
const AppRuntimeServiceRegistryScript = preload("res://app/flow/app_runtime_service_registry.gd")
const AppRuntimeNetworkBootstrapScript = preload("res://app/flow/app_runtime_network_bootstrap.gd")


static func request_initialize(runtime: Node) -> Dictionary:
	if runtime == null:
		return {
			"ok": false,
			"error_code": "RUNTIME_INIT_RUNTIME_INVALID",
			"user_message": "Runtime root is invalid",
		}
	if not runtime.has_method("_ensure_root_nodes"):
		return {
			"ok": false,
			"error_code": "RUNTIME_INIT_METHOD_MISSING",
			"user_message": "Runtime root lacks initializer methods",
		}
	runtime._ensure_root_nodes()
	AppRuntimeServiceRegistryScript.ensure_foundation(runtime)
	runtime._ensure_resume_state_store()
	AppNavigationCoordinatorScript.ensure_navigation(runtime)
	AppRuntimeNetworkBootstrapScript.ensure_components(runtime)
	AppRuntimeServiceRegistryScript.ensure_front_use_cases(runtime)
	AppNavigationCoordinatorScript.ensure_boot_state(runtime)
	return {"ok": true}
