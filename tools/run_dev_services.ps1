param(
    [string]$ProjectPath = '',
    [string]$PowerShellExe = 'powershell',
    [switch]$SkipDb,
    [switch]$SkipMigration,
    [switch]$LogSQL,
    [string]$GodotExecutable = 'Godot_console.exe',
    [string]$LogDir = ''
)

Write-Host '[deprecated] tools/run_dev_services.ps1 -> use tools/run-services.ps1' -ForegroundColor Yellow

& (Join-Path $PSScriptRoot 'run-services.ps1') `
    -Profile dev `
    -ProjectPath $ProjectPath `
    -PowerShellExe $PowerShellExe `
    -SkipDb:$SkipDb `
    -SkipMigration:$SkipMigration `
    -LogSQL:$LogSQL `
    -GodotExecutable $GodotExecutable `
    -LogDir $LogDir
