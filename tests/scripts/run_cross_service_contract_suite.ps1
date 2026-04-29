param(
    [string]$GodotExe = (Join-Path $PSScriptRoot '..\..\godot_binary\Godot.exe'),
    [string]$ProjectPath = ''
)

if ($PSVersionTable.PSVersion.Major -ge 7) {
    $PSNativeCommandUseErrorActionPreference = $false
}

if ([string]::IsNullOrWhiteSpace($ProjectPath)) {
    $ProjectPath = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
} else {
    $ProjectPath = (Resolve-Path -LiteralPath $ProjectPath).Path
}

$wrapper = Join-Path $ProjectPath 'tests\scripts\run_gut_suite.ps1'
if (-not (Test-Path -LiteralPath $wrapper)) {
    Write-Error "missing wrapper script: $wrapper"
    exit 1
}

$reportDir = Join-Path $ProjectPath 'tests\reports\latest'
$null = New-Item -ItemType Directory -Force -Path $reportDir

$startedAt = Get-Date
$results = @()
$passed = @()
$failed = @()

$goSteps = @(
    @{
        name = 'dsm_internal_auth_contract'
        workdir = Join-Path $ProjectPath 'services\ds_manager_service'
        command = 'go test ./internal/httpapi -run "TestDSMInternalRoutesRejectMissingOrInvalidSignature|TestDSMInternalRoutesAcceptSignedRequests"'
    },
    @{
        name = 'ds_control_plane_lifecycle'
        workdir = Join-Path $ProjectPath 'services\ds_manager_service'
        command = 'go test ./internal/httpapi -run "TestDSControlPlaneLifecycleAllocateReadyActiveReap|TestDSControlPlaneMarksFailedWhenProcessExitFails"'
    },
    @{
        name = 'game_internal_battle_manifest_handler'
        workdir = Join-Path $ProjectPath 'services\game_service'
        command = 'go test ./internal/httpapi -run "^TestInternalBattleManifest"'
    },
    @{
        name = 'game_internal_assignment_handler'
        workdir = Join-Path $ProjectPath 'services\game_service'
        command = 'go test ./internal/httpapi -run "^TestInternalAssignmentCommit"'
    },
    @{
        name = 'game_internal_finalize_handler'
        workdir = Join-Path $ProjectPath 'services\game_service'
        command = 'go test ./internal/httpapi -run "^TestInternalFinalize"'
    },
    @{
        name = 'room_wsapi_registry_contracts'
        workdir = Join-Path $ProjectPath 'services\room_service'
        command = 'go test ./internal/wsapi ./internal/registry -run "TestWSDirectoryVisibility|TestRegistry"'
    }
)

foreach ($step in $goSteps) {
    Write-Host ("==> [cross_service_contract_suite] {0}" -f $step.name)
    Push-Location $step.workdir
    $output = Invoke-Expression $step.command 2>&1
    $exitCode = $LASTEXITCODE
    Pop-Location

    $status = if ($exitCode -eq 0) { 'PASS' } else { 'FAIL' }
    $results += [pscustomobject]@{
        name = $step.name
        type = 'go'
        status = $status
        exit_code = $exitCode
        output = (($output | Out-String).TrimEnd())
    }
    if ($status -eq 'PASS') { $passed += $step.name } else { $failed += $step.name }
}

& $wrapper `
    -GodotExe $GodotExe `
    -ProjectPath $ProjectPath `
    -SuiteName 'cross_service_contract_suite_godot' `
    -ReportBaseName 'cross_service_contract_suite_godot' `
    -TestFiles @(
        'res://tests/integration/e2e/battle_entry_invalid_ticket_e2e_test.gd',
        'res://tests/integration/e2e/battle_resume_window_e2e_test.gd',
        'res://tests/integration/e2e/battle_finalize_payload_e2e_test.gd'
    )

$godotExitCode = $LASTEXITCODE
$godotReportJson = Join-Path $reportDir 'cross_service_contract_suite_godot_latest.json'
$godotSummary = $null
if (Test-Path -LiteralPath $godotReportJson) {
    $godotSummary = Get-Content -LiteralPath $godotReportJson -Raw | ConvertFrom-Json
}

if ($godotSummary -ne $null) {
    $results += [pscustomobject]@{
        name = 'cross_service_contract_godot'
        type = 'godot'
        status = [string]$godotSummary.status
        exit_code = [int]$godotSummary.gut_exit_code
        output = [string]$godotSummary.output
        total_tests = [int]$godotSummary.total_tests
        failed_count = [int]$godotSummary.failed_count
        raw_xml_path = [string]$godotSummary.raw_xml_path
    }
    if ([string]$godotSummary.status -eq 'PASS') {
        $passed += 'cross_service_contract_godot'
    } else {
        $failed += 'cross_service_contract_godot'
    }
} else {
    $results += [pscustomobject]@{
        name = 'cross_service_contract_godot'
        type = 'godot'
        status = 'FAIL'
        exit_code = $godotExitCode
        output = 'missing cross_service_contract_suite_godot_latest.json'
    }
    $failed += 'cross_service_contract_godot'
}

$finishedAt = Get-Date
$summary = [ordered]@{
    suite_name = 'cross_service_contract_suite'
    started_at = $startedAt.ToString('s')
    finished_at = $finishedAt.ToString('s')
    duration_seconds = [Math]::Round((New-TimeSpan -Start $startedAt -End $finishedAt).TotalSeconds, 3)
    godot_exe = $GodotExe
    project_path = $ProjectPath
    git_commit = (& git -C $ProjectPath rev-parse --short HEAD).Trim()
    passed_count = $passed.Count
    failed_count = $failed.Count
    passed = $passed
    failed = $failed
    results = $results
}

$textLines = @()
$textLines += 'cross_service_contract_suite Summary'
$textLines += ('started_at: {0}' -f $summary.started_at)
$textLines += ('finished_at: {0}' -f $summary.finished_at)
$textLines += ('duration_seconds: {0}' -f $summary.duration_seconds)
$textLines += ('godot_exe: {0}' -f $summary.godot_exe)
$textLines += ('project_path: {0}' -f $summary.project_path)
$textLines += ('git_commit: {0}' -f $summary.git_commit)
$textLines += ('passed_count: {0}' -f $summary.passed_count)
$textLines += ('failed_count: {0}' -f $summary.failed_count)
if ($passed.Count -gt 0) {
    $textLines += 'passed:'
    foreach ($name in $passed) { $textLines += ('  PASS {0}' -f $name) }
}
if ($failed.Count -gt 0) {
    $textLines += 'failed:'
    foreach ($name in $failed) { $textLines += ('  FAIL {0}' -f $name) }
}

$textPath = Join-Path $reportDir 'cross_service_contract_suite_latest.txt'
$jsonPath = Join-Path $reportDir 'cross_service_contract_suite_latest.json'
$textLines | Set-Content -LiteralPath $textPath
($summary | ConvertTo-Json -Depth 8) | Set-Content -LiteralPath $jsonPath

Write-Host ''
Write-Host ('[cross_service_contract_suite] pass={0} fail={1}' -f $summary.passed_count, $summary.failed_count)
Write-Host ('ReportTxt: {0}' -f $textPath)
Write-Host ('ReportJson: {0}' -f $jsonPath)

if ($summary.failed_count -gt 0) {
    exit 1
}
exit 0
