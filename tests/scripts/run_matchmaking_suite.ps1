param(
    [string]$GodotExe = 'F:\Godot\Godot.exe',
    [string]$ProjectPath = 'D:\code\Personal\QQTang'
)

if ($PSVersionTable.PSVersion.Major -ge 7) {
    $PSNativeCommandUseErrorActionPreference = $false
}

$tests = @(
    'res://tests/unit/network/matchmade_room_policy_test.gd',
    'res://tests/unit/network/server_match_finalize_reporter_test.gd',
    'res://tests/integration/front/lobby_matchmaking_queue_flow_test.gd',
    'res://tests/integration/front/lobby_match_assignment_to_room_test.gd',
    'res://tests/integration/front/settlement_server_summary_sync_test.gd',
    'res://tests/integration/network/matchmade_room_auto_start_test.gd',
    'res://tests/integration/network/match_finalize_idempotence_probe_test.gd',
    'res://tests/smoke/matchmaking/matchmaking_ranked_e2e_smoke_test.gd'
)

$failed = @()
foreach ($test in $tests) {
    Write-Host "==> $test"
    & $GodotExe --headless --path $ProjectPath --script 'res://tests/cli/run_test.gd' -- $test
    if ($LASTEXITCODE -ne 0) {
        $failed += $test
    }
}

if ($failed.Count -gt 0) {
    Write-Host "Matchmaking suite failed:"
    $failed | ForEach-Object { Write-Host "  FAIL $_" }
    exit 1
}

Write-Host 'Matchmaking suite passed.'
exit 0
