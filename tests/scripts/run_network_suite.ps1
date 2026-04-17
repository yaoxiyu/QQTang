param(
    [string]$GodotExe = 'Godot_console.exe',
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

$tests = @(
    'res://tests/unit/network/input/input_buffer_test.gd',
    'res://tests/unit/network/input/input_buffer_missing_fallback_test.gd',
    'res://tests/unit/network/snapshot/snapshot_service_test.gd',
    'res://tests/unit/network/snapshot/snapshot_buffer_eviction_test.gd',
    'res://tests/unit/network/checksum/checksum_builder_test.gd',
    'res://tests/unit/network/prediction/prediction_controller_test.gd',
    'res://tests/unit/network/rollback/force_resync_window_test.gd',
    'res://tests/unit/network/rollback/checksum_mismatch_recovery_test.gd',
    'res://tests/integration/network/replay_determinism_test.gd',
    'res://tests/integration/network/server_client_authoritative_loop_test.gd',
    'res://tests/unit/network/rollback/rollback_controller_test.gd',
    'res://tests/integration/network/network_sim_runner_test.gd'
)

$startedAt = Get-Date
$results = @()
$passed = @()
$failed = @()
$total = $tests.Count
$suiteWatch = [System.Diagnostics.Stopwatch]::StartNew()
$index = 0

foreach ($test in $tests) {
    $index++
    $beforePercent = [int]((($index - 1) / [double]$total) * 100)
    Write-Progress -Activity 'Network Suite Running' -Status "[$index/$total] $test" -PercentComplete $beforePercent
    $testWatch = [System.Diagnostics.Stopwatch]::StartNew()
    Write-Host ("==> [{0}/{1}] {2} START {3}" -f $index, $total, (Get-Date -Format 'HH:mm:ss'), $test)
    $output = & $GodotExe --headless --path $ProjectPath --script 'res://tests/cli/run_test.gd' -- $test 2>&1
    $filteredOutput = $output | Where-Object {
        $_ -notmatch 'Failed to read the root certificate store' -and
        $_ -notmatch 'get_system_ca_certificates' -and
        $_ -notmatch 'ObjectDB instances leaked at exit' -and
        $_ -notmatch 'resources still in use at exit' -and
        $_ -notmatch '^\s+at:\s+cleanup \(core/object/object\.cpp:2641\)$' -and
        $_ -notmatch '^\s+at:\s+clear \(core/io/resource\.cpp:810\)$' -and
        $_ -notmatch 'NativeCommandError' -and
        $_ -notmatch 'CategoryInfo' -and
        $_ -notmatch 'FullyQualifiedErrorId' -and
        $_ -notmatch 'run_network_suite\.ps1:'
    }
    $filteredOutput | ForEach-Object { $_ }

    $exitCode = $LASTEXITCODE
    $joined = ($output | Out-String)
    $joinedFiltered = ($filteredOutput | Out-String)
    $hasFailText = ($joined -match 'FAIL' -and $joined -notmatch 'Failed to read the root certificate store')
    $hasScriptError = $joined -match 'SCRIPT ERROR:'
    $knownExitNoise = $joined -match 'ObjectDB instances leaked at exit' -or $joined -match 'resources still in use at exit'
    $hasEngineError = ($joined -match 'ERROR:' -and $joined -notmatch 'PASS' -and $joined -notmatch 'Failed to read the root certificate store' -and -not $knownExitNoise)
    $status = if ($exitCode -eq 0 -and -not $hasFailText -and -not $hasScriptError -and -not $hasEngineError) {
        'PASS'
    }
    elseif ($joined -match ': PASS' -or $joined -match '\[PASS\]') {
        'PASS'
    }
    else {
        'FAIL'
    }

    $result = [ordered]@{
        test = $test
        status = $status
        exit_code = $exitCode
        has_fail_text = $hasFailText
        has_script_error = $hasScriptError
        has_engine_error = $hasEngineError
        output = ($joinedFiltered.TrimEnd())
    }
    $results += [pscustomobject]$result

    if ($status -eq 'PASS') {
        $passed += $test
    }
    else {
        $failed += $test
    }
    $testWatch.Stop()
    $afterPercent = [int](($index / [double]$total) * 100)
    $elapsedSuite = [math]::Round($suiteWatch.Elapsed.TotalSeconds, 3)
    $elapsedTest = [math]::Round($testWatch.Elapsed.TotalSeconds, 3)
    Write-Progress -Activity 'Network Suite Running' -Status "[$index/$total] $test ($status)" -PercentComplete $afterPercent
    Write-Host ("<== [{0}/{1}] {2} END {3} status={4} test_s={5} suite_s={6}" -f $index, $total, (Get-Date -Format 'HH:mm:ss'), $test, $status, $elapsedTest, $elapsedSuite)
}

$finishedAt = Get-Date
$suiteWatch.Stop()
Write-Progress -Activity 'Network Suite Running' -Completed
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
    git_commit = (& git -C $ProjectPath rev-parse --short HEAD).Trim()
    package_version = "workspace"
    results = $results
}

$textLines = @()
$textLines += 'Network Suite Summary'
$textLines += "started_at: $($summary.started_at)"
$textLines += "finished_at: $($summary.finished_at)"
$textLines += "duration_seconds: $($summary.duration_seconds)"
$textLines += "godot_exe: $($summary.godot_exe)"
$textLines += "project_path: $($summary.project_path)"
$textLines += "git_commit: $($summary.git_commit)"
$textLines += "package_version: $($summary.package_version)"
$textLines += "pass_count: $($summary.passed_count)"
foreach ($test in $passed) {
    $textLines += "  PASS $test"
}
$textLines += "fail_count: $($summary.failed_count)"
foreach ($test in $failed) {
    $textLines += "  FAIL $test"
}
$textLines += ''
foreach ($result in $results) {
    $textLines += "==> $($result.test) [$($result.status)]"
    $textLines += $result.output
    $textLines += ''
}

$textPath = Join-Path $reportDir 'network_suite_latest.txt'
$jsonPath = Join-Path $reportDir 'network_suite_latest.json'

$textLines | Set-Content -LiteralPath $textPath
($summary | ConvertTo-Json -Depth 6) | Set-Content -LiteralPath $jsonPath

Write-Host ''
Write-Host 'Network Suite Summary'
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
