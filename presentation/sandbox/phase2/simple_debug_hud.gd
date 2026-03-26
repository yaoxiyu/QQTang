class_name Phase2SimpleDebugHud
extends Label


func _ready() -> void:
	horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	vertical_alignment = VERTICAL_ALIGNMENT_TOP
	text = "Phase2 Sandbox HUD"


func apply_metrics(metrics: Dictionary) -> void:
	var lines: Array[String] = [
		"Phase2 Battle Sandbox",
		"Phase: %s" % String(metrics.get("match_phase_text", "unknown")),
		"Result: %s" % String(metrics.get("match_result_text", "pending")),
		"LocalTick: %d" % int(metrics.get("local_tick", 0)),
		"ServerTick: %d" % int(metrics.get("server_tick", 0)),
		"SnapshotTick: %d" % int(metrics.get("snapshot_tick", 0)),
		"PredictedTick: %d" % int(metrics.get("predicted_tick", 0)),
		"Ack A/B: %d / %d" % [
			int(metrics.get("ack_a", -1)),
			int(metrics.get("ack_b", -1))
		],
		"Checksum S/A/B: %d / %d / %d" % [
			int(metrics.get("checksum", 0)),
			int(metrics.get("checksum_a", 0)),
			int(metrics.get("checksum_b", 0))
		],
		"Sync: %s" % String(metrics.get("sync_note", "n/a")),
		"",
		"Server",
	]

	for entry in metrics.get("server_positions", []):
		lines.append(String(entry))

	lines.append("")
	lines.append("Client A Confirmed")
	for entry in metrics.get("client_a_positions", []):
		lines.append(String(entry))

	lines.append("Client A Predicted")
	for entry in metrics.get("predicted_a_positions", []):
		lines.append(String(entry))
	lines.append(String(metrics.get("prediction_note_a", "")))

	lines.append("")
	lines.append("Client B Confirmed")
	for entry in metrics.get("client_b_positions", []):
		lines.append(String(entry))

	lines.append("Client B Predicted")
	for entry in metrics.get("predicted_b_positions", []):
		lines.append(String(entry))
	lines.append(String(metrics.get("prediction_note_b", "")))

	text = "\n".join(lines)
