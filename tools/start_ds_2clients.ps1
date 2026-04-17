param(
    [string]$GodotDir = '',
    [string]$ProjectPath = '',
    [int]$ClientCount = 2,
    [switch]$UseConsoleClients,
    [switch]$Wait
)

Write-Host '[deprecated] tools/start_ds_2clients.ps1 now only launches clients; use tools/start-clients.ps1' -ForegroundColor Yellow

& (Join-Path $PSScriptRoot 'start-clients.ps1') `
    -ProjectPath $ProjectPath `
    -GodotDir $GodotDir `
    -Count $ClientCount `
    -StartIndex 1 `
    -UserSlotPrefix 'client' `
    -UseConsoleClient:$UseConsoleClients `
    -Wait:$Wait
