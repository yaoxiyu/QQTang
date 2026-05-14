param(
    [switch]$WithGut,
    [string]$GodotExe = (Join-Path $PSScriptRoot '..\..\external\godot_binary\Godot.exe'),
    [string]$ProjectPath = ''
)

if ($PSVersionTable.PSVersion.Major -ge 7) {
    $PSNativeCommandUseErrorActionPreference = $false
}

$suiteName = 'validation'
$reportBaseName = 'validation_latest'

$repoRoot = if ([string]::IsNullOrWhiteSpace($ProjectPath)) {
    (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
} else {
    (Resolve-Path $ProjectPath).Path
}

$reportDir = Join-Path $repoRoot 'tests\reports\latest'
$rawReportDir = Join-Path $repoRoot 'tests\reports\raw'
$null = New-Item -ItemType Directory -Path $reportDir -Force
$null = New-Item -ItemType Directory -Path $rawReportDir -Force

$startedAt = Get-Date
$results = @()
$passed = @()
$failed = @()

function Invoke-Step {
    param(
        [string]$Name,
        [scriptblock]$Action,
        [string]$Type = 'command',
        [string]$ReportHint = ''
    )

    Write-Host ("==> [{0}] {1}" -f $suiteName, $Name)
    $output = @()
    $exitCode = 0
    $status = 'PASS'
    $global:LASTEXITCODE = 0

    try {
        $output = & $Action 2>&1
        $exitCode = if ($null -eq $global:LASTEXITCODE) { 0 } else { [int]$global:LASTEXITCODE }
        if ($exitCode -ne 0) {
            $status = 'FAIL'
        }
    }
    catch {
        $status = 'FAIL'
        $exitCode = if ($null -eq $LASTEXITCODE) { 1 } else { [int]$LASTEXITCODE }
        $output = @($_.Exception.Message)
    }

    $entry = [pscustomobject]@{
        name = $Name
        type = $Type
        status = $status
        exit_code = $exitCode
        report_hint = $ReportHint
        output = (($output | Out-String).TrimEnd())
    }

    $script:results += $entry
    if ($status -eq 'PASS') {
        $script:passed += $Name
    } else {
        $script:failed += $Name
    }
}

$protoScript = Join-Path $repoRoot 'scripts\proto\generate_proto.ps1'
$crossServiceScript = Join-Path $repoRoot 'tests\scripts\run_cross_service_contract_suite.ps1'
$pythonTestScript = Join-Path $repoRoot 'tests\scripts\run_python_contract_tests.py'
$gdStyleCheckScript = Join-Path $repoRoot 'tools\lint\check_gdscript_style.py'
$sensitiveLogPatternScript = Join-Path $repoRoot 'scripts\validation\check_sensitive_log_patterns.ps1'
$gutScript = Join-Path $repoRoot 'tests\scripts\run_gut_suite.ps1'
$releaseSanityScript = Join-Path $repoRoot 'tools\release\release_sanity_check.py'
$csharpProj = Join-Path $repoRoot 'tests\csharp\QQTang.RoomClient.Tests\QQTang.RoomClient.Tests.csproj'

Invoke-Step -Name 'proto_generate' -Type 'script' -Action {
    & $protoScript
}

$goServices = @(
    'room_service',
    'game_service',
    'ds_manager_service',
    'ds_agent',
    'account_service',
    'shared/contentmanifest'
)

foreach ($service in $goServices) {
    $servicePath = $service -replace '/', '\'
    $workdir = Join-Path $repoRoot ("services\{0}" -f $servicePath)
    $safeServiceName = $service -replace '[\\/]', '_'
    Invoke-Step -Name ("go_test_{0}" -f $safeServiceName) -Type 'go' -Action {
        Push-Location $workdir
        try {
            go test ./...
        }
        finally {
            Pop-Location
        }
    }
}

Invoke-Step -Name 'check_room_manifest' -Type 'script' -Action {
    $manifestPath = Join-Path $repoRoot 'build/generated/room_manifest/room_manifest.json'
    if (-not (Test-Path $manifestPath)) {
        throw "room_manifest.json missing. Run scripts/content/run_content_pipeline.ps1 first."
    }
    Write-Host "room_manifest.json present at $manifestPath"
}

Invoke-Step -Name 'dotnet_room_client_tests' -Type 'dotnet' -Action {
    dotnet test $csharpProj -v minimal
}

Invoke-Step -Name 'python_contract_tests' -Type 'script' -ReportHint 'tests/reports/latest/python_contract_tests_latest.json' -Action {
    python $pythonTestScript --timeout 120
}

Invoke-Step -Name 'gdscript_style_check' -Type 'script' -Action {
    python $gdStyleCheckScript
}

Invoke-Step -Name 'sensitive_log_pattern_check' -Type 'script' -Action {
    & $sensitiveLogPatternScript -RepoRoot $repoRoot
}

Invoke-Step -Name 'cross_service_contract_suite' -Type 'script' -ReportHint 'tests/reports/latest/cross_service_contract_suite_latest.{txt,json}' -Action {
    & $crossServiceScript -GodotExe $GodotExe -ProjectPath $repoRoot
}

if ($WithGut) {
    Invoke-Step -Name 'gut_suite' -Type 'script' -ReportHint 'tests/reports/latest/gut_suite_latest.{txt,json}' -Action {
        & $gutScript -GodotExe $GodotExe -ProjectPath $repoRoot -TestDirs @(
            'res://tests/integration/e2e'
        )
    }
} else {
    $results += [pscustomobject]@{
        name = 'gut_suite'
        type = 'script'
        status = 'SKIP'
        exit_code = 0
        report_hint = 'tests/reports/latest/gut_suite_latest.{txt,json}'
        output = 'Skipped (use -WithGut to enable).'
    }
}

Invoke-Step -Name 'release_sanity' -Type 'python' -Action {
    py -3 $releaseSanityScript
}

$finishedAt = Get-Date
$summary = [ordered]@{
    suite_name = $suiteName
    started_at = $startedAt.ToString('s')
    finished_at = $finishedAt.ToString('s')
    duration_seconds = [Math]::Round((New-TimeSpan -Start $startedAt -End $finishedAt).TotalSeconds, 3)
    project_path = $repoRoot
    godot_exe = $GodotExe
    with_gut = [bool]$WithGut
    passed_count = $passed.Count
    failed_count = $failed.Count
    skipped_count = (@($results | Where-Object { $_.status -eq 'SKIP' })).Count
    passed = $passed
    failed = $failed
    results = $results
}

$textLines = @()
$textLines += ('{0} Summary' -f $suiteName)
$textLines += ('started_at: {0}' -f $summary.started_at)
$textLines += ('finished_at: {0}' -f $summary.finished_at)
$textLines += ('duration_seconds: {0}' -f $summary.duration_seconds)
$textLines += ('project_path: {0}' -f $summary.project_path)
$textLines += ('godot_exe: {0}' -f $summary.godot_exe)
$textLines += ('with_gut: {0}' -f $summary.with_gut)
$textLines += ('passed_count: {0}' -f $summary.passed_count)
$textLines += ('failed_count: {0}' -f $summary.failed_count)
$textLines += ('skipped_count: {0}' -f $summary.skipped_count)
if ($passed.Count -gt 0) {
    $textLines += 'passed:'
    foreach ($name in $passed) { $textLines += ('  PASS {0}' -f $name) }
}
if ($failed.Count -gt 0) {
    $textLines += 'failed:'
    foreach ($name in $failed) { $textLines += ('  FAIL {0}' -f $name) }
}
$textLines += 'reports:'
$textLines += ('  tests/reports/latest/{0}.txt' -f $reportBaseName)
$textLines += ('  tests/reports/latest/{0}.json' -f $reportBaseName)
$textLines += '  tests/reports/latest/cross_service_contract_suite_latest.txt'
$textLines += '  tests/reports/latest/cross_service_contract_suite_latest.json'

$textPath = Join-Path $reportDir ('{0}.txt' -f $reportBaseName)
$jsonPath = Join-Path $reportDir ('{0}.json' -f $reportBaseName)

$textLines | Set-Content -LiteralPath $textPath
($summary | ConvertTo-Json -Depth 8) | Set-Content -LiteralPath $jsonPath

Write-Host ''
Write-Host ('[{0}] pass={1} fail={2} skip={3}' -f $suiteName, $summary.passed_count, $summary.failed_count, $summary.skipped_count)
Write-Host ('ReportTxt: {0}' -f $textPath)
Write-Host ('ReportJson: {0}' -f $jsonPath)

if ($summary.failed_count -gt 0) {
    exit 1
}
exit 0
