package runtime

import (
	"strings"
	"testing"
)

func TestGodotRunnerBuildArgsDoesNotIncludeBattleTicketSecret(t *testing.T) {
	runner := NewGodotRunner(GodotRunnerConfig{
		GodotExecutable: "external/godot_binary/Godot.exe",
		ProjectRoot:     "/app/project",
		BattleScenePath: "res://scenes/network/dedicated_server_scene.tscn",
	})

	args := runner.buildArgs(StartSpec{
		BattleID:      "battle-1",
		AssignmentID:  "assign-1",
		MatchID:       "match-1",
		AdvertiseHost: "qqt-ds-slot-001",
		AdvertisePort: 9000,
		ListenPort:    9000,
	})
	joined := strings.Join(args, " ")
	if strings.Contains(joined, "battle_ticket_secret") || strings.Contains(joined, "qqt-battle-ticket-secret") {
		t.Fatalf("args contain battle ticket secret flag: %v", args)
	}
	for _, expected := range []string{
		"--headless",
		"res://scenes/network/dedicated_server_scene.tscn",
		"--qqt-battle-id=battle-1",
		"--qqt-assignment-id=assign-1",
		"--qqt-match-id=match-1",
		"--qqt-ds-host=qqt-ds-slot-001",
		"--qqt-ds-port=9000",
	} {
		if !contains(args, expected) {
			t.Fatalf("args missing %q: %v", expected, args)
		}
	}
	for _, unexpected := range []string{"--path", "/app/project"} {
		if contains(args, unexpected) {
			t.Fatalf("args should not contain %q: %v", unexpected, args)
		}
	}
}

func TestGodotRunnerBuildArgsAllowsDefaultExportScene(t *testing.T) {
	runner := NewGodotRunner(GodotRunnerConfig{
		GodotExecutable: "external/godot_binary/Godot.exe",
		BattleScenePath: "",
	})

	args := runner.buildArgs(StartSpec{
		BattleID:      "battle-1",
		AssignmentID:  "assign-1",
		MatchID:       "match-1",
		AdvertiseHost: "qqt-ds-slot-001",
		AdvertisePort: 20000,
		ListenPort:    9000,
	})
	if contains(args, "res://scenes/network/dedicated_server_scene.tscn") {
		t.Fatalf("exported binary args should rely on the exported main scene: %v", args)
	}
	if !contains(args, "--") {
		t.Fatalf("args missing Godot/user argument separator: %v", args)
	}
	if !contains(args, "--qqt-ds-port=9000") {
		t.Fatalf("exported binary should listen on container port, got: %v", args)
	}
	if contains(args, "--qqt-ds-port=20000") {
		t.Fatalf("exported binary must not listen on advertised host port: %v", args)
	}
}

func contains(values []string, expected string) bool {
	for _, value := range values {
		if value == expected {
			return true
		}
	}
	return false
}
