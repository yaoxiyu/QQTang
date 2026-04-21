package queue

const (
	QueuePhaseIdle              = "idle"
	QueuePhaseQueued            = "queued"
	QueuePhaseAssignmentPending = "assignment_pending"
	QueuePhaseAllocatingBattle  = "allocating_battle"
	QueuePhaseEntryReady        = "entry_ready"
	QueuePhaseCompleted         = "completed"
)

const (
	QueueTerminalReasonNone              = "none"
	QueueTerminalReasonClientCancelled   = "client_cancelled"
	QueueTerminalReasonAssignmentExpired = "assignment_expired"
	QueueTerminalReasonAssignmentMissing = "assignment_missing"
	QueueTerminalReasonAllocationFailed  = "allocation_failed"
	QueueTerminalReasonMatchFinalized    = "match_finalized"
	QueueTerminalReasonHeartbeatTimeout  = "heartbeat_timeout"
)

const (
	AllocationPhaseNone       = ""
	AllocationPhasePending    = "pending_allocate"
	AllocationPhaseAllocating = "allocating"
	AllocationPhaseReady      = "allocated"
	AllocationPhaseFailed     = "alloc_failed"
)
