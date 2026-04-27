extends "res://tests/gut/base/qqt_contract_test.gd"

const FORBIDDEN_PROTOCOL_PATTERNS := [
	"const INPUT_FRAME",
	"\"INPUT_FRAME\"",
	".INPUT_FRAME",
]
const SCANNED_PATHS := [
	"res://network/session/runtime/authority_runtime.gd",
	"res://network/runtime/battle_dedicated_server_bootstrap.gd",
	"res://network/session/battle_session_adapter.gd",
	"res://network/transport/battle_transport_channels.gd",
	"res://network/transport/transport_message_types.gd",
]


func test_high_frequency_input_frame_protocol_is_removed() -> void:
	var violations: Array[String] = []
	for path in SCANNED_PATHS:
		var text := _read_text(path)
		for pattern in FORBIDDEN_PROTOCOL_PATTERNS:
			if text.find(pattern) >= 0:
				violations.append("%s: %s" % [path, pattern])
	assert_true(violations.is_empty(), "legacy INPUT_FRAME protocol references must stay removed:\n%s" % "\n".join(violations))


func _read_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	return file.get_as_text()
