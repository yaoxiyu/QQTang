param(
    [string]$GodotExe = 'D:\Godot\Godot_console.exe',
    [string]$ProjectPath = 'D:\code\QQTang'
)

if ($PSVersionTable.PSVersion.Major -ge 7) {
    $PSNativeCommandUseErrorActionPreference = $false
}

$reportDir = Join-Path $ProjectPath 'tests\reports\latest'
New-Item -ItemType Directory -Force -Path $reportDir | Out-Null
$cliAppData = Join-Path $ProjectPath 'tests\cli\appdata'
New-Item -ItemType Directory -Force -Path $cliAppData | Out-Null
$originalAppData = $env:APPDATA
$env:APPDATA = $cliAppData

$startedAt = Get-Date
$suiteWatch = [System.Diagnostics.Stopwatch]::StartNew()
$results = @()
$passed = @()
$failed = @()

$steps = @(
    @{
        name = 'dsm_internal_auth_contract'
        type = 'go'
        workdir = Join-Path $ProjectPath 'services\ds_manager_service'
        command = 'go test ./internal/httpapi -run "TestInternalRoutesRejectMissingOrInvalidAuth|TestInternalRoutesAllowSignedAuth"'
    },
    @{
        name = 'manual_room_two_phase_contract'
        type = 'go'
        workdir = Join-Path $ProjectPath 'services\game_service'
        command = 'go test ./internal/battlealloc -run TestManualRoomBattleTwoPhaseContract'
    },
    @{
        name = 'ds_control_plane_lifecycle'
        type = 'go'
        workdir = Join-Path $ProjectPath 'services\ds_manager_service'
        command = 'go test ./internal/httpapi -run TestInternalBattleLifecycleWithSignedAuth'
    },
    @{
        name = 'battle_entry_invalid_ticket_e2e'
        type = 'godot'
        test = 'res://tests/integration/e2e/battle_entry_invalid_ticket_e2e_test.gd'
    },
    @{
        name = 'battle_resume_window_e2e'
        type = 'godot'
        test = 'res://tests/integration/e2e/battle_resume_window_e2e_test.gd'
    }
)

$total = $steps.Count
$index = 0
foreach ($step in $steps) {
    $index++
    $beforePercent = [int]((($index - 1) / [double]$total) * 100)
    Write-Progress -Activity 'Cross-Service Contract Suite' -Status "[$index/$total] $($step.name)" -PercentComplete $beforePercent
    $stepWatch = [System.Diagnostics.Stopwatch]::StartNew()
    Write-Host ("==> [{0}/{1}] {2} START {3}" -f $index, $total, (Get-Date -Format 'HH:mm:ss'), $step.name)

    $output = @()
    if ($step.type -eq 'go') {
        Push-Location $step.workdir
        $output = Invoke-Expression $step.command 2>&1
        $exitCode = $LASTEXITCODE
        Pop-Location
    } else {
        $output = & $GodotExe --headless --path $ProjectPath --script 'res://tests/cli/run_test.gd' -- $step.test 2>&1
        $exitCode = $LASTEXITCODE
    }

    $filteredOutput = $output | Where-Object {
        $_ -notmatch 'Failed to read the root certificate store' -and
        $_ -notmatch 'get_system_ca_certificates' -and
        $_ -notmatch 'ObjectDB instances leaked at exit' -and
        $_ -notmatch 'resources still in use at exit' -and
        $_ -notmatch '^\s+at:\s+cleanup \(core/object/object\.cpp:2641\)$' -and
        $_ -notmatch '^\s+at:\s+clear \(core/io/resource\.cpp:810\)$'
    }
    $filteredOutput | ForEach-Object { $_ }

    $joined = ($output | Out-String)
    $joinedFiltered = ($filteredOutput | Out-String)
    $status = 'PASS'
    if ($exitCode -ne 0) { $status = 'FAIL' }
    if ($joined -match 'SCRIPT ERROR:' -or $joined -match '\[FAIL\]' -or ($joined -match ': FAIL' -and $joined -notmatch ': PASS')) {
        $status = 'FAIL'
    }

    $results += [pscustomobject]@{
        name = $step.name
        type = $step.type
        status = $status
        exit_code = $exitCode
        output = $joinedFiltered.TrimEnd()
    }
    if ($status -eq 'PASS') { $passed += $step.name } else { $failed += $step.name }

    $stepWatch.Stop()
    $afterPercent = [int](($index / [double]$total) * 100)
    $elapsedSuite = [math]::Round($suiteWatch.Elapsed.TotalSeconds, 3)
    $elapsedStep = [math]::Round($stepWatch.Elapsed.TotalSeconds, 3)
    Write-Progress -Activity 'Cross-Service Contract Suite' -Status "[$index/$total] $($step.name) ($status)" -PercentComplete $afterPercent
    Write-Host ("<== [{0}/{1}] {2} END {3} status={4} step_s={5} suite_s={6}" -f $index, $total, (Get-Date -Format 'HH:mm:ss'), $step.name, $status, $elapsedStep, $elapsedSuite)
}

$suiteWatch.Stop()
Write-Progress -Activity 'Cross-Service Contract Suite' -Completed
$finishedAt = Get-Date

$summary = [ordered]@{
    started_at = $startedAt.ToString('s')
    finished_at = $finishedAt.ToString('s')
    duration_seconds = [math]::Round((New-TimeSpan -Start $startedAt -End $finishedAt).TotalSeconds, 3)
    godot_exe = $GodotExe
    project_path = $ProjectPath
    git_commit = (& git -C $ProjectPath rev-parse --short HEAD).Trim()
    package_version = "workspace"
    passed_count = $passed.Count
    failed_count = $failed.Count
    passed = $passed
    failed = $failed
    results = $results
}

$textLines = @()
$textLines += 'Cross-Service Contract Suite Summary'
$textLines += "started_at: $($summary.started_at)"
$textLines += "finished_at: $($summary.finished_at)"
$textLines += "duration_seconds: $($summary.duration_seconds)"
$textLines += "godot_exe: $($summary.godot_exe)"
$textLines += "project_path: $($summary.project_path)"
$textLines += "git_commit: $($summary.git_commit)"
$textLines += "package_version: $($summary.package_version)"
$textLines += "pass_count: $($summary.passed_count)"
foreach ($item in $passed) { $textLines += "  PASS $item" }
$textLines += "fail_count: $($summary.failed_count)"
foreach ($item in $failed) { $textLines += "  FAIL $item" }

$textPath = Join-Path $reportDir 'cross_service_contract_suite_latest.txt'
$jsonPath = Join-Path $reportDir 'cross_service_contract_suite_latest.json'
$textLines | Set-Content -LiteralPath $textPath
($summary | ConvertTo-Json -Depth 8) | Set-Content -LiteralPath $jsonPath

Write-Host ''
Write-Host 'Cross-Service Contract Suite Summary'
Write-Host "Passed: $($passed.Count)"
$passed | ForEach-Object { Write-Host "  PASS $_" }
Write-Host "Failed: $($failed.Count)"
$failed | ForEach-Object { Write-Host "  FAIL $_" }
Write-Host "ReportTxt: $textPath"
Write-Host "ReportJson: $jsonPath"

$env:APPDATA = $originalAppData
if ($failed.Count -gt 0) {
    exit 1
}

exit 0
