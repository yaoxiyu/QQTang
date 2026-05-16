param(
    [string]$GodotExe = (Join-Path $PSScriptRoot '..\..\external\godot_binary\Godot.exe'),
    [string]$ProjectPath = '',
    [string]$SuiteName = 'gut_suite',
    [string[]]$TestDirs = @(),
    [string[]]$TestFiles = @(),
    [bool]$IncludeSubdirs = $true,
    [string]$ReportBaseName = 'gut_suite',
    [string]$ReportRoot = 'tests\reports\latest',
    [string]$RawReportRoot = 'tests\reports\raw'
)

if ($PSVersionTable.PSVersion.Major -ge 7) {
    $PSNativeCommandUseErrorActionPreference = $false
}

$startedAt = Get-Date
if ([string]::IsNullOrWhiteSpace($ProjectPath)) {
    $ProjectPath = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
} else {
    $ProjectPath = (Resolve-Path -LiteralPath $ProjectPath).Path
}
$reportDir = Join-Path $ProjectPath $ReportRoot
$rawReportDir = Join-Path $ProjectPath $RawReportRoot
$cliAppData = Join-Path $ProjectPath 'tests\cli\appdata'
$null = New-Item -ItemType Directory -Force -Path $reportDir
$null = New-Item -ItemType Directory -Force -Path $rawReportDir
$null = New-Item -ItemType Directory -Force -Path $cliAppData

$originalAppData = $env:APPDATA
$env:APPDATA = $cliAppData

$resolvedTestDirs = @()
foreach ($dir in $TestDirs) {
    $trimmed = [string]$dir
    if (-not [string]::IsNullOrWhiteSpace($trimmed)) {
        $resolvedTestDirs += $trimmed.Trim()
    }
}
$resolvedTestFiles = @()
foreach ($file in $TestFiles) {
    $trimmed = [string]$file
    if (-not [string]::IsNullOrWhiteSpace($trimmed)) {
        $resolvedTestFiles += $trimmed.Trim()
    }
}

$rawFileName = '{0}_latest.xml' -f $ReportBaseName
$rawXmlPath = Join-Path $rawReportDir $rawFileName
$rawXmlResPath = ('res://{0}/{1}' -f ($RawReportRoot -replace '\\', '/'), $rawFileName)
if (Test-Path -LiteralPath $rawXmlPath) {
    Remove-Item -LiteralPath $rawXmlPath -Force -ErrorAction SilentlyContinue
}

$classCachePath = Join-Path $ProjectPath '.godot\global_script_class_cache.cfg'
$needsImport = $true
if (Test-Path -LiteralPath $classCachePath) {
    $hasGutClass = Select-String -LiteralPath $classCachePath -Pattern 'GutTest' -SimpleMatch -Quiet -ErrorAction SilentlyContinue
    $needsImport = -not [bool]$hasGutClass
}
if ($needsImport) {
    Write-Host ('==> [{0}] warmup import for GUT class cache' -f $SuiteName)
    & cmd /c "`"$GodotExe`" --headless --path `"$ProjectPath`" --import" 2>&1 | Out-Null
}

$gutArgs = @(
    '--headless',
    '--path', $ProjectPath,
    '-s', 'res://addons/gut/gut_cmdln.gd',
    '--',
    '-gexit',
    '-gconfig=',
    '-gprefix=',
    '-gsuffix=_test.gd',
    '-gfailure_error_types=gut,push_error',
    ('-gjunit_xml_file={0}' -f $rawXmlResPath)
)
if ($IncludeSubdirs) {
    $gutArgs += '-ginclude_subdirs'
}
foreach ($dir in $resolvedTestDirs) {
    $gutArgs += ('-gdir={0}' -f $dir)
}
foreach ($file in $resolvedTestFiles) {
    $gutArgs += ('-gtest={0}' -f $file)
}

Write-Host ('==> [{0}] running GUT' -f $SuiteName)
Write-Host ('GodotExe: {0}' -f $GodotExe)
Write-Host ('ProjectPath: {0}' -f $ProjectPath)
Write-Host ('TestDirs: {0}' -f ($resolvedTestDirs -join ', '))
Write-Host ('TestFiles: {0}' -f ($resolvedTestFiles -join ', '))
Write-Host ('RawXml: {0}' -f $rawXmlPath)

$rawOutput = & $GodotExe @gutArgs 2>&1
$gutExitCode = if ($null -eq $LASTEXITCODE) { 0 } else { [int]$LASTEXITCODE }

$filteredOutput = $rawOutput | Where-Object {
    $_ -notmatch 'Failed to read the root certificate store' -and
    $_ -notmatch 'get_system_ca_certificates' -and
    $_ -notmatch 'RID allocations of type .* were leaked at exit' -and
    $_ -notmatch 'NativeCommandError' -and
    $_ -notmatch 'CategoryInfo' -and
    $_ -notmatch 'FullyQualifiedErrorId'
}

$totalTests = 0
$failedTests = @()
$xmlParseError = ''
function Get-OptionalXmlProperty {
    param(
        [object]$Node,
        [string]$Name
    )
    if ($null -eq $Node) {
        return $null
    }
    $property = $Node.PSObject.Properties[$Name]
    if ($null -eq $property) {
        return $null
    }
    return $property.Value
}
$waitDeadline = (Get-Date).AddSeconds(300)
while ((-not (Test-Path -LiteralPath $rawXmlPath) -or ((Get-Item -LiteralPath $rawXmlPath -ErrorAction SilentlyContinue).Length -le 0)) -and (Get-Date) -lt $waitDeadline) {
    Start-Sleep -Milliseconds 100
}
if (Test-Path -LiteralPath $rawXmlPath) {
    try {
        [xml]$junit = Get-Content -LiteralPath $rawXmlPath -Raw
        $suiteNodes = @($junit.testsuites.testsuite)
        foreach ($suite in $suiteNodes) {
            foreach ($testcase in @($suite.testcase)) {
                $totalTests += 1
                $failureNode = Get-OptionalXmlProperty -Node $testcase -Name 'failure'
                $errorNode = Get-OptionalXmlProperty -Node $testcase -Name 'error'
                if ($failureNode -ne $null -or $errorNode -ne $null) {
                    $failureText = ''
                    if ($failureNode -ne $null) {
                        $failureText = [string](Get-OptionalXmlProperty -Node $failureNode -Name '#cdata-section')
                        if ([string]::IsNullOrWhiteSpace($failureText)) {
                            $failureText = [string](Get-OptionalXmlProperty -Node $failureNode -Name 'message')
                        }
                    } elseif ($errorNode -ne $null) {
                        $failureText = [string](Get-OptionalXmlProperty -Node $errorNode -Name '#cdata-section')
                        if ([string]::IsNullOrWhiteSpace($failureText)) {
                            $failureText = [string](Get-OptionalXmlProperty -Node $errorNode -Name 'message')
                        }
                    }
                    $failedTests += [pscustomobject]@{
                        suite = [string]$suite.name
                        test = [string]$testcase.name
                        message = ($failureText.Trim())
                    }
                }
            }
        }
    } catch {
        $xmlParseError = $_.Exception.Message
    }
} else {
    $xmlParseError = 'raw xml report not found'
}

$finishedAt = Get-Date
$failedCount = $failedTests.Count
$passedCount = [Math]::Max(0, $totalTests - $failedCount)
if ([string]::IsNullOrWhiteSpace($xmlParseError) -and $totalTests -eq 0) {
    $xmlParseError = 'no tests collected'
}
$status = if ($gutExitCode -eq 0 -and $failedCount -eq 0 -and [string]::IsNullOrWhiteSpace($xmlParseError)) { 'PASS' } else { 'FAIL' }

$summary = [ordered]@{
    suite_name = $SuiteName
    started_at = $startedAt.ToString('s')
    finished_at = $finishedAt.ToString('s')
    duration_seconds = [Math]::Round((New-TimeSpan -Start $startedAt -End $finishedAt).TotalSeconds, 3)
    status = $status
    godot_exe = $GodotExe
    project_path = $ProjectPath
    test_dirs = $resolvedTestDirs
    test_files = $resolvedTestFiles
    report_base_name = $ReportBaseName
    raw_xml_path = $rawXmlPath
    raw_xml_res_path = $rawXmlResPath
    gut_exit_code = $gutExitCode
    total_tests = $totalTests
    passed_count = $passedCount
    failed_count = $failedCount
    xml_parse_error = $xmlParseError
    failed_tests = $failedTests
    output = (($filteredOutput | Out-String).TrimEnd())
}

$textPath = Join-Path $reportDir ('{0}_latest.txt' -f $ReportBaseName)
$jsonPath = Join-Path $reportDir ('{0}_latest.json' -f $ReportBaseName)

$textLines = @()
$textLines += ('{0} Summary' -f $SuiteName)
$textLines += ('started_at: {0}' -f $summary.started_at)
$textLines += ('finished_at: {0}' -f $summary.finished_at)
$textLines += ('duration_seconds: {0}' -f $summary.duration_seconds)
$textLines += ('status: {0}' -f $summary.status)
$textLines += ('godot_exe: {0}' -f $summary.godot_exe)
$textLines += ('project_path: {0}' -f $summary.project_path)
$textLines += ('raw_xml_path: {0}' -f $summary.raw_xml_path)
$textLines += ('total_tests: {0}' -f $summary.total_tests)
$textLines += ('passed_count: {0}' -f $summary.passed_count)
$textLines += ('failed_count: {0}' -f $summary.failed_count)
if (-not [string]::IsNullOrWhiteSpace($summary.xml_parse_error)) {
    $textLines += ('xml_parse_error: {0}' -f $summary.xml_parse_error)
}
if ($failedTests.Count -gt 0) {
    $textLines += ''
    $textLines += 'failed_tests:'
    foreach ($item in $failedTests) {
        $textLines += ('  FAIL {0}::{1}' -f $item.suite, $item.test)
        if (-not [string]::IsNullOrWhiteSpace($item.message)) {
            $textLines += ('    {0}' -f $item.message)
        }
    }
}
if (-not [string]::IsNullOrWhiteSpace($summary.output)) {
    $textLines += ''
    $textLines += 'raw_output:'
    $textLines += $summary.output
}

$textLines | Set-Content -LiteralPath $textPath
($summary | ConvertTo-Json -Depth 8) | Set-Content -LiteralPath $jsonPath

Write-Host ''
Write-Host ('[{0}] status={1} total={2} pass={3} fail={4}' -f $SuiteName, $summary.status, $summary.total_tests, $summary.passed_count, $summary.failed_count)
Write-Host ('ReportTxt: {0}' -f $textPath)
Write-Host ('ReportJson: {0}' -f $jsonPath)

$env:APPDATA = $originalAppData
if ($summary.status -ne 'PASS') {
    exit 1
}
exit 0
