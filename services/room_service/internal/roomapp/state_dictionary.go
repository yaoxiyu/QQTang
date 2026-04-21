package roomapp

const (
	RoomPhaseIdle             = "idle"
	RoomPhaseQueueEntering    = "queue_entering"
	RoomPhaseQueueActive      = "queue_active"
	RoomPhaseQueueCancelling  = "queue_cancelling"
	RoomPhaseBattleAllocating = "battle_allocating"
	RoomPhaseBattleEntryReady = "battle_entry_ready"
	RoomPhaseBattleEntering   = "battle_entering"
	RoomPhaseInBattle         = "in_battle"
	RoomPhaseReturningToRoom  = "returning_to_room"
	RoomPhaseClosed           = "closed"
)

const (
	RoomReasonNone                    = "none"
	RoomReasonQueueCancelled          = "queue_cancelled"
	RoomReasonQueueFailed             = "queue_failed"
	RoomReasonAssignmentExpired       = "assignment_expired"
	RoomReasonMatchFinalized          = "match_finalized"
	RoomReasonManualBattleStarted     = "manual_battle_started"
	RoomReasonBattleEntryAcknowledged = "battle_entry_acknowledged"
	RoomReasonBattleFinished          = "battle_finished"
	RoomReasonReturnCompleted         = "return_completed"
	RoomReasonRoomClosed              = "room_closed"
)

const (
	MemberPhaseIdle         = "idle"
	MemberPhaseReady        = "ready"
	MemberPhaseQueueLocked  = "queue_locked"
	MemberPhaseInBattle     = "in_battle"
	MemberPhaseDisconnected = "disconnected"
)

const (
	QueuePhaseIdle              = "idle"
	QueuePhaseQueued            = "queued"
	QueuePhaseAssignmentPending = "assignment_pending"
	QueuePhaseAllocatingBattle  = "allocating_battle"
	QueuePhaseEntryReady        = "entry_ready"
	QueuePhaseCompleted         = "completed"
)

const (
	QueueReasonNone              = "none"
	QueueReasonClientCancelled   = "client_cancelled"
	QueueReasonAssignmentExpired = "assignment_expired"
	QueueReasonAssignmentMissing = "assignment_missing"
	QueueReasonAllocationFailed  = "allocation_failed"
	QueueReasonMatchFinalized    = "match_finalized"
	QueueReasonHeartbeatTimeout  = "heartbeat_timeout"
)

const (
	BattlePhaseIdle       = "idle"
	BattlePhaseAllocating = "allocating"
	BattlePhaseReady      = "ready"
	BattlePhaseEntering   = "entering"
	BattlePhaseActive     = "active"
	BattlePhaseReturning  = "returning"
	BattlePhaseCompleted  = "completed"
)

const (
	BattleReasonNone              = "none"
	BattleReasonManualStart       = "manual_start"
	BattleReasonMatchAssignment   = "match_assignment"
	BattleReasonAllocationFailed  = "allocation_failed"
	BattleReasonEntryAcknowledged = "entry_acknowledged"
	BattleReasonBattleFinished    = "battle_finished"
	BattleReasonReturnCompleted   = "return_completed"
)
