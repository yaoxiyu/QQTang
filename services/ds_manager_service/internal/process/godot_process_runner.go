package process

import (
	"context"
	"fmt"
	"log"
	"os/exec"
	"sync"
)

type RunnerConfig struct {
	GodotExecutable    string
	ProjectRoot        string
	BattleScenePath    string
	BattleTicketSecret string
}

type RunningProcess struct {
	BattleID string
	Cmd      *exec.Cmd
	Cancel   context.CancelFunc
}

type GodotProcessRunner struct {
	config    RunnerConfig
	mu        sync.Mutex
	processes map[string]*RunningProcess
}

func NewGodotProcessRunner(cfg RunnerConfig) *GodotProcessRunner {
	return &GodotProcessRunner{
		config:    cfg,
		processes: make(map[string]*RunningProcess),
	}
}

func (r *GodotProcessRunner) Start(battleID, assignmentID, matchID, host string, port int) (int, error) {
	r.mu.Lock()
	defer r.mu.Unlock()

	if _, exists := r.processes[battleID]; exists {
		return 0, fmt.Errorf("process for battle %s already running", battleID)
	}

	ctx, cancel := context.WithCancel(context.Background())

	args := []string{
		"--headless",
	}
	if r.config.ProjectRoot != "" {
		args = append(args, "--path", r.config.ProjectRoot)
	}
	args = append(args, r.config.BattleScenePath, "--")
	args = append(args,
		fmt.Sprintf("--qqt-battle-id=%s", battleID),
		fmt.Sprintf("--qqt-assignment-id=%s", assignmentID),
		fmt.Sprintf("--qqt-match-id=%s", matchID),
		fmt.Sprintf("--qqt-ds-host=%s", host),
		fmt.Sprintf("--qqt-ds-port=%d", port),
		fmt.Sprintf("--qqt-battle-ticket-secret=%s", r.config.BattleTicketSecret),
	)

	cmd := exec.CommandContext(ctx, r.config.GodotExecutable, args...)

	if err := cmd.Start(); err != nil {
		cancel()
		return 0, fmt.Errorf("failed to start godot process: %w", err)
	}

	pid := cmd.Process.Pid
	rp := &RunningProcess{
		BattleID: battleID,
		Cmd:      cmd,
		Cancel:   cancel,
	}
	r.processes[battleID] = rp

	go r.waitForExit(battleID, rp)

	log.Printf("[ds_manager] started battle DS pid=%d battle_id=%s port=%d", pid, battleID, port)
	return pid, nil
}

func (r *GodotProcessRunner) Kill(battleID string) error {
	r.mu.Lock()
	rp, ok := r.processes[battleID]
	r.mu.Unlock()
	if !ok {
		return fmt.Errorf("no process for battle %s", battleID)
	}
	rp.Cancel()
	return nil
}

func (r *GodotProcessRunner) IsRunning(battleID string) bool {
	r.mu.Lock()
	defer r.mu.Unlock()
	_, ok := r.processes[battleID]
	return ok
}

func (r *GodotProcessRunner) waitForExit(battleID string, rp *RunningProcess) {
	err := rp.Cmd.Wait()
	r.mu.Lock()
	delete(r.processes, battleID)
	r.mu.Unlock()
	if err != nil {
		log.Printf("[ds_manager] battle DS exited with error battle_id=%s err=%v", battleID, err)
	} else {
		log.Printf("[ds_manager] battle DS exited normally battle_id=%s", battleID)
	}
}

type ExitCallback func(battleID string, err error)

func (r *GodotProcessRunner) StartWithCallback(battleID, assignmentID, matchID, host string, port int, onExit ExitCallback) (int, error) {
	r.mu.Lock()
	defer r.mu.Unlock()

	if _, exists := r.processes[battleID]; exists {
		return 0, fmt.Errorf("process for battle %s already running", battleID)
	}

	ctx, cancel := context.WithCancel(context.Background())

	args := []string{
		"--headless",
	}
	if r.config.ProjectRoot != "" {
		args = append(args, "--path", r.config.ProjectRoot)
	}
	args = append(args, r.config.BattleScenePath, "--")
	args = append(args,
		fmt.Sprintf("--qqt-battle-id=%s", battleID),
		fmt.Sprintf("--qqt-assignment-id=%s", assignmentID),
		fmt.Sprintf("--qqt-match-id=%s", matchID),
		fmt.Sprintf("--qqt-ds-host=%s", host),
		fmt.Sprintf("--qqt-ds-port=%d", port),
		fmt.Sprintf("--qqt-battle-ticket-secret=%s", r.config.BattleTicketSecret),
	)

	cmd := exec.CommandContext(ctx, r.config.GodotExecutable, args...)

	if err := cmd.Start(); err != nil {
		cancel()
		return 0, fmt.Errorf("failed to start godot process: %w", err)
	}

	pid := cmd.Process.Pid
	rp := &RunningProcess{
		BattleID: battleID,
		Cmd:      cmd,
		Cancel:   cancel,
	}
	r.processes[battleID] = rp

	go func() {
		err := rp.Cmd.Wait()
		r.mu.Lock()
		delete(r.processes, battleID)
		r.mu.Unlock()
		if onExit != nil {
			onExit(battleID, err)
		}
	}()

	log.Printf("[ds_manager] started battle DS pid=%d battle_id=%s port=%d", pid, battleID, port)
	return pid, nil
}
