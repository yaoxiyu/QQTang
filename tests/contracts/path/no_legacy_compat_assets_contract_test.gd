extends "res://tests/gut/base/qqt_contract_test.gd"

const FORBIDDEN_PATHS := [
	"res://gameplay/front/flow/",
	"res://gameplay/network/session/",
	"res://network/runtime/legacy/",
	"res://network/session/legacy/",
	"res://network/runtime/dedicated_server_bootstrap.gd",
	"res://network/session/runtime/server_room_runtime.gd",
	"res://network/session/runtime/server_room_runtime_compat_impl.gd",
	"res://network/session/runtime/legacy_room_runtime_bridge.gd",
]


func test_forbidden_legacy_compat_assets_do_not_exist() -> void:
	for path in FORBIDDEN_PATHS:
		assert_false(ResourceLoader.exists(path), "legacy/compat asset should not exist: %s" % path)
		if path.ends_with("/"):
			assert_false(DirAccess.dir_exists_absolute(path), "legacy/compat directory should not exist: %s" % path)
