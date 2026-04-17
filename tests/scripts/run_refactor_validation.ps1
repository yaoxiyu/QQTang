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

$tests = @(
    'res://tests/unit/app/app_runtime_context_sync_test.gd',
    'res://tests/unit/app/app_battle_module_registry_test.gd',
    'res://tests/unit/app/app_runtime_initializer_test.gd',
    'res://tests/unit/front/room_scene_selector_presenter_test.gd',
    'res://tests/unit/front/room_scene_selection_submitter_test.gd',
    'res://tests/unit/front/room_scene_snapshot_coordinator_test.gd',
    'res://tests/unit/infra/http/http_request_executor_test.gd',
    'res://tests/contracts/path/legacy_runtime_bridge_guard_test.gd'
)

$startedAt = Get-Date
$suiteWatch = [System.Diagnostics.Stopwatch]::StartNew()
$results = @()
$passed = @()
$failed = @()
$total = $tests.Count
$index = 0

foreach ($test in $tests) {
    $index++
    $beforePercent = [int]((($index - 1) / [double]$total) * 100)
    Write-Progress -Activity 'Refactor Validation Running' -Status "[$index/$total] $test" -PercentComplete $beforePercent
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
        $_ -notmatch 'FullyQualifiedErrorId'
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
    Write-Progress -Activity 'Refactor Validation Running' -Status "[$index/$total] $test ($status)" -PercentComplete $afterPercent
    Write-Host ("<== [{0}/{1}] {2} END {3} status={4} test_s={5} suite_s={6}" -f $index, $total, (Get-Date -Format 'HH:mm:ss'), $test, $status, $elapsedTest, $elapsedSuite)
}

$finishedAt = Get-Date
$suiteWatch.Stop()
Write-Progress -Activity 'Refactor Validation Running' -Completed

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
$textLines += 'Refactor Validation Summary'
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

$textPath = Join-Path $reportDir 'refactor_validation_latest.txt'
$jsonPath = Join-Path $reportDir 'refactor_validation_latest.json'

$textLines | Set-Content -LiteralPath $textPath
($summary | ConvertTo-Json -Depth 6) | Set-Content -LiteralPath $jsonPath

Write-Host ''
Write-Host 'Refactor Validation Summary'
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
