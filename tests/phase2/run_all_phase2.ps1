param(
    [string]$GodotExe = 'D:\Godot\Godot_v4.6.1-stable_win64_console.exe',
    [string]$ProjectPath = 'D:\code\QQTang'
)

$reportDir = Join-Path $ProjectPath 'tests\phase2\reports'
New-Item -ItemType Directory -Force -Path $reportDir | Out-Null

$tests = @(
    'res://tests/phase2/unit/input/test_input_buffer_phase2.gd',
    'res://tests/phase2/unit/input/test_input_buffer_missing_fallback.gd',
    'res://tests/phase2/unit/snapshot/test_snapshot_service.gd',
    'res://tests/phase2/unit/snapshot/test_snapshot_buffer_eviction.gd',
    'res://tests/phase2/unit/checksum/test_checksum_builder_phase2.gd',
    'res://tests/phase2/unit/prediction/test_prediction_controller.gd',
    'res://tests/phase2/unit/rollback/test_force_resync_window.gd',
    'res://tests/phase2/unit/rollback/test_checksum_mismatch_recovery.gd',
    'res://tests/phase2/sim/test_replay_determinism.gd',
    'res://tests/phase2/sync/test_server_client_authoritative_loop.gd',
    'res://tests/phase2/recovery/test_rollback_controller.gd',
    'res://tests/phase2/network/test_network_sim_runner.gd'
)

$startedAt = Get-Date
$results = @()
$passed = @()
$failed = @()

foreach ($test in $tests) {
    Write-Host "==> $test"
    $output = & $GodotExe --headless --path $ProjectPath --script 'res://tests/phase2/run_test.gd' -- $test 2>&1
    $output | ForEach-Object { $_ }

    $exitCode = $LASTEXITCODE
    $joined = ($output | Out-String)
    $hasFailText = $joined -match 'FAIL - '
    $hasScriptError = $joined -match 'SCRIPT ERROR:'
    $hasEngineError = $joined -match 'ERROR:' -and $joined -notmatch 'PASS'
    $status = if ($exitCode -eq 0 -and -not $hasFailText -and -not $hasScriptError -and -not $hasEngineError) { 'PASS' } else { 'FAIL' }

    $result = [ordered]@{
        test = $test
        status = $status
        exit_code = $exitCode
        has_fail_text = $hasFailText
        has_script_error = $hasScriptError
        has_engine_error = $hasEngineError
        output = ($joined.TrimEnd())
    }
    $results += [pscustomobject]$result

    if ($status -eq 'PASS') {
        $passed += $test
    }
    else {
        $failed += $test
    }
}

$finishedAt = Get-Date
$summary = [ordered]@{
    started_at = $startedAt.ToString('s')
    finished_at = $finishedAt.ToString('s')
    duration_seconds = [math]::Round((New-TimeSpan -Start $startedAt -End $finishedAt).TotalSeconds, 3)
    godot_exe = $GodotExe
    project_path = $ProjectPath
    passed_count = $passed.Count
    failed_count = $failed.Count
    passed = $passed
    failed = $failed
    results = $results
}

$textLines = @()
$textLines += 'Phase2 Test Summary'
$textLines += "Started: $($summary.started_at)"
$textLines += "Finished: $($summary.finished_at)"
$textLines += "DurationSeconds: $($summary.duration_seconds)"
$textLines += "GodotExe: $($summary.godot_exe)"
$textLines += "ProjectPath: $($summary.project_path)"
$textLines += "Passed: $($summary.passed_count)"
foreach ($test in $passed) {
    $textLines += "  PASS $test"
}
$textLines += "Failed: $($summary.failed_count)"
foreach ($test in $failed) {
    $textLines += "  FAIL $test"
}
$textLines += ''
foreach ($result in $results) {
    $textLines += "==> $($result.test) [$($result.status)]"
    $textLines += $result.output
    $textLines += ''
}

$textPath = Join-Path $reportDir 'phase2_latest.txt'
$jsonPath = Join-Path $reportDir 'phase2_latest.json'

$textLines | Set-Content -LiteralPath $textPath
($summary | ConvertTo-Json -Depth 6) | Set-Content -LiteralPath $jsonPath

Write-Host ''
Write-Host 'Phase2 Test Summary'
Write-Host "Passed: $($passed.Count)"
$passed | ForEach-Object { Write-Host "  PASS $_" }
Write-Host "Failed: $($failed.Count)"
$failed | ForEach-Object { Write-Host "  FAIL $_" }
Write-Host "ReportTxt: $textPath"
Write-Host "ReportJson: $jsonPath"

if ($failed.Count -gt 0) {
    exit 1
}

exit 0

