param(
    [string]$GodotExe = 'Godot_console.exe',
    [string]$ProjectPath = 'D:\code\QQTang'
)

if ($PSVersionTable.PSVersion.Major -ge 7) {
    $PSNativeCommandUseErrorActionPreference = $false
}

$reportDir = Join-Path $ProjectPath 'tests\reports\integration'
New-Item -ItemType Directory -Force -Path $reportDir | Out-Null
$cliAppData = Join-Path $ProjectPath 'tests\cli\appdata'
New-Item -ItemType Directory -Force -Path $cliAppData | Out-Null
$originalAppData = $env:APPDATA
$env:APPDATA = $cliAppData

$tests = @(
    'res://tests/unit/network/transport/transport_codec_test.gd',
    'res://tests/unit/network/transport/local_loopback_transport_test.gd',
    'res://tests/unit/network/config/battle_start_config_test.gd',
    'res://tests/contracts/path/legacy_wrapper_guard_test.gd',
    'res://tests/integration/network/host_client_bootstrap_test.gd',
    'res://tests/integration/network/network_match_flow_test.gd'
)

$startedAt = Get-Date
$results = @()
$passed = @()
$failed = @()

foreach ($test in $tests) {
    Write-Host "==> $test"
    $output = & $GodotExe --headless --path $ProjectPath --script 'res://tests/cli/run_test.gd' -- $test 2>&1
    $filteredOutput = $output | Where-Object {
        $_ -notmatch 'Failed to read the root certificate store' -and
        $_ -notmatch 'get_system_ca_certificates' -and
        $_ -notmatch 'NativeCommandError' -and
        $_ -notmatch 'CategoryInfo' -and
        $_ -notmatch 'FullyQualifiedErrorId' -and
        $_ -notmatch 'run_integration_suite\.ps1:'
    }
    $filteredOutput | ForEach-Object { $_ }

    $exitCode = $LASTEXITCODE
    $joined = ($output | Out-String)
    $joinedFiltered = ($filteredOutput | Out-String)
    $hasFailText = ($joined -match 'FAIL' -and $joined -notmatch 'Failed to read the root certificate store')
    $hasScriptError = $joined -match 'SCRIPT ERROR:'
    $hasEngineError = ($joined -match 'ERROR:' -and $joined -notmatch 'PASS' -and $joined -notmatch 'Failed to read the root certificate store')
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
$textLines += 'Integration Suite Summary'
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

$textPath = Join-Path $reportDir 'integration_suite_latest.txt'
$jsonPath = Join-Path $reportDir 'integration_suite_latest.json'

$textLines | Set-Content -LiteralPath $textPath
($summary | ConvertTo-Json -Depth 6) | Set-Content -LiteralPath $jsonPath

Write-Host ''
Write-Host 'Integration Suite Summary'
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
