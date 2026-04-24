param(
    [string]$GodotExe = 'D:\Godot\Godot.exe',
    [string]$SyntaxGodotExe = 'D:\Godot\Godot_console.exe',
    [string]$ProjectPath = '',
    [ValidateSet('windows')]
    [string]$Platform = 'windows',
    [ValidateSet('template_debug', 'template_release')]
    [string]$Target = 'template_debug',
    [string]$Arch = 'x86_64'
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($ProjectPath)) {
    $repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
} else {
    $repoRoot = Resolve-Path -LiteralPath $ProjectPath
}

$syntaxPreflight = Join-Path $repoRoot 'tests\scripts\check_gdscript_syntax.ps1'
$gutWrapper = Join-Path $repoRoot 'tests\scripts\run_gut_suite.ps1'
$nativeBuildScript = Join-Path $repoRoot 'tools\native\build_native.ps1'
$latestReportDir = Join-Path $repoRoot 'tests\reports\latest'
$summaryPath = Join-Path $latestReportDir 'native_suite_latest.txt'

if (-not (Test-Path -LiteralPath $syntaxPreflight)) {
    throw "missing syntax preflight script: $syntaxPreflight"
}
if (-not (Test-Path -LiteralPath $gutWrapper)) {
    throw "missing GUT wrapper script: $gutWrapper"
}
if (-not (Test-Path -LiteralPath $nativeBuildScript)) {
    throw "missing native build script: $nativeBuildScript"
}

if ($Arch -ne 'x86_64') {
    throw "Unsupported arch '$Arch'. Current repo only ships Windows x86_64 qqt_native artifacts."
}

$null = New-Item -ItemType Directory -Force -Path $latestReportDir

$suiteResults = @()

Write-Host "[native_suite] running GDScript syntax preflight"
& $syntaxPreflight -GodotExe $SyntaxGodotExe -ProjectPath $repoRoot
if ($LASTEXITCODE -ne 0) {
    throw "GDScript syntax preflight failed (exit code: $LASTEXITCODE)"
}

Write-Host "[native_suite] building native extension"
& $nativeBuildScript -Platform $Platform -Target $Target -Arch $Arch
if ($LASTEXITCODE -ne 0) {
    throw "Native build failed (exit code: $LASTEXITCODE)"
}

$suiteSpecs = @(
    @{
        SuiteName = 'native_unit_suite'
        ReportBaseName = 'native_unit_suite'
        TestDirs = @('res://tests/unit/native')
    },
    @{
        SuiteName = 'native_integration_suite'
        ReportBaseName = 'native_integration_suite'
        TestDirs = @('res://tests/integration/native')
    },
    @{
        SuiteName = 'native_performance_suite'
        ReportBaseName = 'native_performance_suite'
        TestDirs = @('res://tests/performance/native')
    }
)

foreach ($spec in $suiteSpecs) {
    Write-Host "[native_suite] running $($spec.SuiteName)"
    & $gutWrapper `
        -GodotExe $GodotExe `
        -ProjectPath $repoRoot `
        -SuiteName $spec.SuiteName `
        -ReportBaseName $spec.ReportBaseName `
        -TestDirs $spec.TestDirs

    $exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { [int]$LASTEXITCODE }
    $suiteResults += [pscustomobject]@{
        suite_name = $spec.SuiteName
        report_base_name = $spec.ReportBaseName
        exit_code = $exitCode
        report_txt = Join-Path $latestReportDir ('{0}_latest.txt' -f $spec.ReportBaseName)
    }
    if ($exitCode -ne 0) {
        break
    }
}

$summaryLines = @()
$summaryLines += 'native_suite summary'
$summaryLines += ('project_path: {0}' -f $repoRoot)
$summaryLines += ('godot_exe: {0}' -f $GodotExe)
$summaryLines += ('platform: {0}' -f $Platform)
$summaryLines += ('target: {0}' -f $Target)
$summaryLines += ('arch: {0}' -f $Arch)
$summaryLines += ''
$summaryLines += 'suites:'
foreach ($result in $suiteResults) {
    $summaryLines += ('- {0}: exit_code={1} report={2}' -f $result.suite_name, $result.exit_code, $result.report_txt)
}

$summaryLines | Set-Content -LiteralPath $summaryPath
Write-Host ('[native_suite] summary report: {0}' -f $summaryPath)

if ($suiteResults | Where-Object { $_.exit_code -ne 0 }) {
    exit 1
}
exit 0
