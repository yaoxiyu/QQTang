package runtime

import (
	"context"
	"fmt"
	"log"
	"os"
	"os/exec"
	"strconv"
	"sync"
)

type StartSpec struct {
	LeaseID            string
	BattleID           string
	AssignmentID       string
	MatchID            string
	AdvertiseHost      string
	AdvertisePort      int
	ListenPort         int
	GameServiceBaseURL string
	DSMBaseURL         string
}

type ProcessInfo struct {
	PID int
}

type Runner interface {
	Start(ctx context.Context, spec StartSpec) (ProcessInfo, error)
	Stop() error
	IsRunning() bool
}

type GodotRunnerConfig struct {
	GodotExecutable string
	ProjectRoot     string
	BattleScenePath string
}

type GodotRunner struct {
	config GodotRunnerConfig
	mu     sync.Mutex
	cmd    *exec.Cmd
	cancel context.CancelFunc
}

func NewGodotRunner(cfg GodotRunnerConfig) *GodotRunner {
	return &GodotRunner{config: cfg}
}

func (r *GodotRunner) Start(ctx context.Context, spec StartSpec) (ProcessInfo, error) {
	if spec.BattleID == "" || spec.AssignmentID == "" || spec.MatchID == "" {
		return ProcessInfo{}, fmt.Errorf("battle_id, assignment_id, match_id are required")
	}
	if spec.ListenPort <= 0 && spec.AdvertisePort <= 0 {
		return ProcessInfo{}, fmt.Errorf("listen_port or advertise_port is required")
	}
	if r.config.GodotExecutable == "" {
		return ProcessInfo{}, fmt.Errorf("godot executable is required")
	}

	r.mu.Lock()
	defer r.mu.Unlock()
	if r.cmd != nil {
		return ProcessInfo{}, fmt.Errorf("godot process already running")
	}

	processCtx, cancel := context.WithCancel(ctx)
	args := r.buildArgs(spec)
	cmd := exec.CommandContext(processCtx, r.config.GodotExecutable, args...)
	if r.config.ProjectRoot != "" {
		cmd.Dir = r.config.ProjectRoot
	}
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if spec.GameServiceBaseURL != "" {
		cmd.Env = append(cmd.Environ(), "GAME_SERVICE_BASE_URL="+spec.GameServiceBaseURL)
	}
	if spec.DSMBaseURL != "" {
		cmd.Env = append(cmd.Environ(), "DSM_BASE_URL="+spec.DSMBaseURL)
	}
	log.Printf("[ds_agent] starting godot battle_id=%s assignment_id=%s match_id=%s listen_port=%d advertise=%s:%d game_service_base_url=%s dsm_base_url=%s args=%v",
		spec.BattleID,
		spec.AssignmentID,
		spec.MatchID,
		spec.ListenPort,
		spec.AdvertiseHost,
		spec.AdvertisePort,
		spec.GameServiceBaseURL,
		spec.DSMBaseURL,
		args,
	)
	if err := cmd.Start(); err != nil {
		cancel()
		return ProcessInfo{}, fmt.Errorf("failed to start godot process: %w", err)
	}

	r.cmd = cmd
	r.cancel = cancel
	go r.waitForExit(cmd)
	return ProcessInfo{PID: cmd.Process.Pid}, nil
}

func (r *GodotRunner) Stop() error {
	r.mu.Lock()
	cancel := r.cancel
	r.mu.Unlock()
	if cancel == nil {
		return nil
	}
	cancel()
	return nil
}

func (r *GodotRunner) IsRunning() bool {
	r.mu.Lock()
	defer r.mu.Unlock()
	return r.cmd != nil
}

func (r *GodotRunner) buildArgs(spec StartSpec) []string {
	args := []string{"--headless"}
	if r.config.BattleScenePath != "" {
		args = append(args, r.config.BattleScenePath)
	}
	listenPort := spec.ListenPort
	if listenPort <= 0 {
		listenPort = spec.AdvertisePort
	}
	args = append(args, "--")
	args = append(args,
		"--qqt-battle-id="+spec.BattleID,
		"--qqt-assignment-id="+spec.AssignmentID,
		"--qqt-match-id="+spec.MatchID,
		"--qqt-ds-host="+spec.AdvertiseHost,
		"--qqt-ds-port="+strconv.Itoa(listenPort),
	)
	return args
}

func (r *GodotRunner) waitForExit(cmd *exec.Cmd) {
	err := cmd.Wait()
	if err != nil {
		log.Printf("[ds_agent] godot process exited pid=%d err=%v", cmd.Process.Pid, err)
	} else {
		log.Printf("[ds_agent] godot process exited pid=%d", cmd.Process.Pid)
	}
	r.mu.Lock()
	if r.cmd == cmd {
		r.cmd = nil
		r.cancel = nil
	}
	r.mu.Unlock()
}
