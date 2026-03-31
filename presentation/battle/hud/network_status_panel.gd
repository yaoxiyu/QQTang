class_name NetworkStatusPanel
extends Label

var latency_ms: int = 0
var packet_loss_percent: int = 0
var ack_tick: int = -1
var rollback_count: int = 0
var last_rollback_tick: int = -1
var resync_count: int = 0
var last_resync_tick: int = -1
var predicted_tick: int = 0
var authoritative_tick: int = 0
var snapshot_tick: int = 0
var delivered_messages: int = 0
var dropped_messages: int = 0
var pending_server_messages: int = 0
var prediction_enabled: bool = false
var force_divergence_armed: bool = false
var correction_count: int = 0
var last_correction: String = ""
var network_profile: String = ""
var drop_rate_percent: int = 0
var remote_debug_inputs: bool = false


func _ready() -> void:
	horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_refresh_text()


func apply_network_metrics(metrics: Dictionary) -> void:
	latency_ms = int(metrics.get("latency_ms", 0))
	packet_loss_percent = int(metrics.get("packet_loss_percent", 0))
	ack_tick = int(metrics.get("ack_tick", -1))
	rollback_count = int(metrics.get("rollback_count", 0))
	last_rollback_tick = int(metrics.get("last_rollback_tick", -1))
	resync_count = int(metrics.get("resync_count", 0))
	last_resync_tick = int(metrics.get("last_resync_tick", -1))
	predicted_tick = int(metrics.get("predicted_tick", 0))
	authoritative_tick = int(metrics.get("authoritative_tick", 0))
	snapshot_tick = int(metrics.get("snapshot_tick", 0))
	delivered_messages = int(metrics.get("delivered_messages", 0))
	dropped_messages = int(metrics.get("dropped_messages", 0))
	pending_server_messages = int(metrics.get("pending_server_messages", 0))
	prediction_enabled = bool(metrics.get("prediction_enabled", false))
	force_divergence_armed = bool(metrics.get("force_divergence_armed", false))
	correction_count = int(metrics.get("correction_count", 0))
	last_correction = str(metrics.get("last_correction", ""))
	network_profile = str(metrics.get("network_profile", ""))
	drop_rate_percent = int(metrics.get("drop_rate_percent", 0))
	remote_debug_inputs = bool(metrics.get("remote_debug_inputs", false))
	_refresh_text()


func _refresh_text() -> void:
	var lines := [
		"Latency: %dms" % latency_ms,
		"PacketLoss: %d%%" % packet_loss_percent,
		"AckTick: %d" % ack_tick,
		"PredictedTick: %d" % predicted_tick,
		"AuthoritativeTick: %d" % authoritative_tick,
		"SnapshotTick: %d" % snapshot_tick,
		"RollbackCount: %d" % rollback_count,
		"LastRollbackTick: %d" % last_rollback_tick,
		"ResyncCount: %d" % resync_count,
		"LastResyncTick: %d" % last_resync_tick,
		"CorrectionCount: %d" % correction_count,
		"Delivered: %d" % delivered_messages,
		"Dropped: %d" % dropped_messages,
		"Pending: %d" % pending_server_messages,
		"Prediction: %s" % ("on" if prediction_enabled else "off"),
		"ForceDivergence: %s" % ("armed" if force_divergence_armed else "idle"),
		"DropRate: %d%%" % drop_rate_percent,
		"RemoteDebug: %s" % ("on" if remote_debug_inputs else "off"),
	]
	if not network_profile.is_empty():
		lines.append("Profile: %s" % network_profile)
	if not last_correction.is_empty():
		lines.append("LastCorrection: %s" % last_correction)
	text = "\n".join(lines)
