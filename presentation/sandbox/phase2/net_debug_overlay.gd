class_name Phase2NetDebugOverlay
extends Label


func _ready() -> void:
	horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vertical_alignment = VERTICAL_ALIGNMENT_TOP
	text = "Net Debug Overlay"


func apply_metrics(metrics: Dictionary) -> void:
	var prediction_text := "off"
	if bool(metrics.get("prediction_enabled", false)):
		prediction_text = "on"

	var smoothing_text := "off"
	if bool(metrics.get("smoothing_enabled", false)):
		smoothing_text = "on"

	var lines: Array[String] = [
		"PredictedTick: %d" % int(metrics.get("predicted_tick", 0)),
		"Corrections A/B: %d / %d" % [
			int(metrics.get("correction_a", 0)),
			int(metrics.get("correction_b", 0))
		],
		"RollbackCount: %d" % int(metrics.get("rollback_count", 0)),
		"ResyncCount: %d" % int(metrics.get("resync_count", 0)),
		"Latency: %dms" % int(metrics.get("latency_ms", 0)),
		"PacketLoss: %d%%" % int(metrics.get("packet_loss_percent", 0)),
		"Prediction: %s" % prediction_text,
		"Smoothing: %s" % smoothing_text,
		""
	]

	if bool(metrics.get("diverged", false)):
		lines.append("VISIBLE DIVERGENCE")
		for entry in metrics.get("divergence_lines", []):
			lines.append(String(entry))
	else:
		lines.append("No visible divergence")

	lines.append("")
	if bool(metrics.get("predicted_diverged", false)):
		lines.append("PREDICTION GAP")
		for entry in metrics.get("predicted_divergence_lines", []):
			lines.append(String(entry))
	else:
		lines.append("No prediction gap")

	lines.append("")
	lines.append("P1: WASD + Space")
	lines.append("P2: Arrows + Enter")
	lines.append("F5 Restart  F6 Latency  F7 Loss")
	lines.append("P Pause  O Single Step")

	text = "\n".join(lines)
	modulate = Color(1.0, 0.75, 0.75, 1.0) if bool(metrics.get("diverged", false)) else Color.WHITE
