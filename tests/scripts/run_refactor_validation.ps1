param(
    [string]$GodotExe = (Join-Path $PSScriptRoot '..\..\external\godot_binary\Godot.exe'),
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
    -SuiteName 'refactor_validation' `
    -ReportBaseName 'refactor_validation' `
    -TestDirs @(
        'res://tests/unit/app',
        'res://tests/unit/front',
        'res://tests/unit/infra',
        'res://tests/contracts/path',
        'res://tests/contracts/runtime'
    )

exit $LASTEXITCODE
