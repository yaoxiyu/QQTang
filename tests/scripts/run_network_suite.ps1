param(
    [string]$GodotExe = 'D:\Godot\Godot.exe',
    [string]$ProjectPath = 'D:\code\QQTang'
)

$wrapper = Join-Path $ProjectPath 'tests\scripts\run_gut_suite.ps1'
if (-not (Test-Path -LiteralPath $wrapper)) {
    Write-Error "missing wrapper script: $wrapper"
    exit 1
}

& $wrapper `
    -GodotExe $GodotExe `
    -ProjectPath $ProjectPath `
    -SuiteName 'network_suite' `
    -ReportBaseName 'network_suite' `
    -TestDirs @(
        'res://tests/unit/network',
        'res://tests/integration/network',
        'res://tests/smoke/multi_match'
    )

exit $LASTEXITCODE
