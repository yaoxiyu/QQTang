param(
    [switch]$WithGut,
    [string]$GodotExe = (Join-Path $PSScriptRoot '..\..\external\godot_binary\Godot.exe'),
    [string]$ProjectPath = ''
)

$validationScript = Join-Path $PSScriptRoot 'run_validation.ps1'

if ($WithGut) {
    & $validationScript -WithGut -GodotExe $GodotExe -ProjectPath $ProjectPath
} else {
    & $validationScript -GodotExe $GodotExe -ProjectPath $ProjectPath
}
exit $LASTEXITCODE
