extends "res://tests/gut/base/qqt_contract_test.gd"

const FORBIDDEN_RUNTIME_BRIDGES := [
	"res://network/session/runtime/legacy_room_runtime_bridge.gd",
	"res://network/session/runtime/server_room_runtime_compat_impl.gd",
	"res://network/session/runtime/server_room_runtime.gd",
]


func test_legacy_runtime_bridge_assets_do_not_exist() -> void:
	for path in FORBIDDEN_RUNTIME_BRIDGES:
		assert_false(ResourceLoader.exists(path), "legacy runtime bridge asset should not exist: %s" % path)
