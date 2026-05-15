extends "res://tests/gut/base/qqt_unit_test.gd"

const ServiceUrlBuilderScript = preload("res://app/infra/http/service_url_builder.gd")


func test_main() -> void:
	var ok := true
	var prefix := "service_url_builder_test"
	OS.set_environment("QQT_ALLOW_INSECURE_HTTP", "1")
	OS.set_environment("QQT_REQUIRE_HTTPS", "")

	var game_from_base := ServiceUrlBuilderScript.normalize_service_base_url("http://game_service/internal", 18081, "QQT_GAME_SERVICE_SCHEME")
	ok = qqt_check(game_from_base.find("://game_service:18081") >= 0, "normalize should pin game service default port when base url omits port", prefix) and ok

	var dsm_from_host_port := ServiceUrlBuilderScript.build_ds_manager_base_url("ds_manager_service", 0, 18090)
	ok = qqt_check(dsm_from_host_port.find("://ds_manager_service:18090") >= 0, "ds manager builder should use default port", prefix) and ok

	var dsm_from_short_addr := ServiceUrlBuilderScript.normalize_service_base_url(":18090", 18090, "QQT_DSM_SERVICE_SCHEME")
	ok = qqt_check(dsm_from_short_addr.find("://127.0.0.1:18090") >= 0, "normalize should expand :port short address", prefix) and ok

	var endpoint_without_port: Dictionary = ServiceUrlBuilderScript.parse_host_and_explicit_port("http://game_service/internal")
	ok = qqt_check(String(endpoint_without_port.get("host", "")) == "game_service", "endpoint parser should resolve host from base url without explicit port", prefix) and ok
	ok = qqt_check(int(endpoint_without_port.get("port", -1)) == 0, "endpoint parser should keep port=0 when base url omits explicit port", prefix) and ok

	var endpoint_with_port: Dictionary = ServiceUrlBuilderScript.parse_host_and_explicit_port("http://game_service:18081/internal")
	ok = qqt_check(int(endpoint_with_port.get("port", 0)) == 18081, "endpoint parser should read explicit port", prefix) and ok

	OS.set_environment("QQT_ALLOW_INSECURE_HTTP", "")

	if not ok:
		push_error("service_url_builder_test failed")
