param(
    [string]$GodotExe = 'D:\Godot\Godot.exe',
    [string]$ProjectPath = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
)

$wrapper = Join-Path $ProjectPath 'tests\scripts\run_gut_suite.ps1'
if (-not (Test-Path -LiteralPath $wrapper)) {
    Write-Error "missing wrapper script: $wrapper"
    exit 1
}

& $wrapper `
    -GodotExe $GodotExe `
    -ProjectPath $ProjectPath `
    -SuiteName 'matchmaking_suite' `
    -ReportBaseName 'matchmaking_suite' `
    -TestDirs @(
        'res://tests/unit/network',
        'res://tests/integration/front',
        'res://tests/integration/network',
        'res://tests/smoke/matchmaking'
    )

exit $LASTEXITCODE
