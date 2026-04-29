package state

import (
	"fmt"
	"sync"
	"time"
)

const (
	AgentStateIdle          = "idle"
	AgentStateAssignedMock  = "assigned_mock"
	AgentStateGodotStarting = "godot_starting"
	AgentStateGodotStarted  = "godot_started"
	AgentStateFailed        = "failed"
)

type Snapshot struct {
	State        string    `json:"state"`
	LeaseID      string    `json:"lease_id,omitempty"`
	BattleID     string    `json:"battle_id,omitempty"`
	AssignmentID string    `json:"assignment_id,omitempty"`
	MatchID      string    `json:"match_id,omitempty"`
	BattlePort   int       `json:"battle_port,omitempty"`
	PID          int       `json:"pid,omitempty"`
	StartedAt    time.Time `json:"started_at,omitempty"`
}

type Store struct {
	mu       sync.Mutex
	snapshot Snapshot
}

func NewStore(battlePort int) *Store {
	return &Store{
		snapshot: Snapshot{
			State:      AgentStateIdle,
			BattlePort: battlePort,
		},
	}
}

func (s *Store) Snapshot() Snapshot {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.snapshot
}

func (s *Store) AssignMock(leaseID string, battleID string, assignmentID string, matchID string) (Snapshot, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.snapshot.State != AgentStateIdle {
		return Snapshot{}, fmt.Errorf("agent state %s does not allow assign", s.snapshot.State)
	}
	if leaseID == "" || battleID == "" || assignmentID == "" || matchID == "" {
		return Snapshot{}, fmt.Errorf("lease_id, battle_id, assignment_id, match_id are required")
	}
	s.snapshot.State = AgentStateAssignedMock
	s.snapshot.LeaseID = leaseID
	s.snapshot.BattleID = battleID
	s.snapshot.AssignmentID = assignmentID
	s.snapshot.MatchID = matchID
	s.snapshot.StartedAt = time.Now().UTC()
	return s.snapshot, nil
}

func (s *Store) BeginGodotAssign(leaseID string, battleID string, assignmentID string, matchID string) (Snapshot, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.snapshot.State != AgentStateIdle {
		return Snapshot{}, fmt.Errorf("agent state %s does not allow assign", s.snapshot.State)
	}
	if leaseID == "" || battleID == "" || assignmentID == "" || matchID == "" {
		return Snapshot{}, fmt.Errorf("lease_id, battle_id, assignment_id, match_id are required")
	}
	s.snapshot.State = AgentStateGodotStarting
	s.snapshot.LeaseID = leaseID
	s.snapshot.BattleID = battleID
	s.snapshot.AssignmentID = assignmentID
	s.snapshot.MatchID = matchID
	s.snapshot.StartedAt = time.Now().UTC()
	return s.snapshot, nil
}

func (s *Store) MarkGodotStarted(pid int) Snapshot {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.snapshot.State = AgentStateGodotStarted
	s.snapshot.PID = pid
	return s.snapshot
}

func (s *Store) MarkFailed() Snapshot {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.snapshot.State = AgentStateFailed
	return s.snapshot
}

func (s *Store) Reset() Snapshot {
	s.mu.Lock()
	defer s.mu.Unlock()
	battlePort := s.snapshot.BattlePort
	s.snapshot = Snapshot{
		State:      AgentStateIdle,
		BattlePort: battlePort,
	}
	return s.snapshot
}
