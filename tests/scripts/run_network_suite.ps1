param(
    [string]$GodotExe = (Join-Path $PSScriptRoot '..\..\godot_binary\Godot.exe'),
    [string]$ProjectPath = ''
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($ProjectPath)) {
    $repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
} else {
    $repoRoot = Resolve-Path -LiteralPath $ProjectPath
}

$wrapper = Join-Path $repoRoot 'tests\scripts\run_gut_suite.ps1'
if (-not (Test-Path -LiteralPath $wrapper)) {
    Write-Error "missing wrapper script: $wrapper"
    exit 1
}

& $wrapper `
    -GodotExe $GodotExe `
    -ProjectPath $repoRoot `
    -SuiteName 'network_suite' `
    -ReportBaseName 'network_suite' `
    -TestDirs @(
        'res://tests/unit/network',
        'res://tests/integration/network',
        'res://tests/smoke/multi_match'
    )

exit $LASTEXITCODE
