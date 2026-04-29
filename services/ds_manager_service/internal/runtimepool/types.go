package runtimepool

type AllocationSpec struct {
	BattleID            string
	AssignmentID        string
	MatchID             string
	SourceRoomID        string
	ExpectedMemberCount int
	HostHint            string
	WaitReady           bool
	IdempotencyKey      string
	LeaseTTLSec         int
}

type AllocationResult struct {
	OK              bool   `json:"ok"`
	DSInstanceID    string `json:"ds_instance_id"`
	LeaseID         string `json:"lease_id"`
	AllocationState string `json:"allocation_state"`
	ServerHost      string `json:"server_host"`
	ServerPort      int    `json:"server_port"`
	ControlEndpoint string `json:"control_endpoint"`
	PoolState       string `json:"pool_state"`
	ErrorCode       string `json:"error_code"`
	Message         string `json:"message"`
}
