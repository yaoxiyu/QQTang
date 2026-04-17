param(
    [string]$GodotDir = '',
    [string]$ProjectPath = '',
    [int]$ClientIndex = 1,
    [string]$UserSlot = '',
    [string]$LogRoot = '',
    [switch]$UseConsoleClient,
    [switch]$Wait
)

$prefix = if ([string]::IsNullOrWhiteSpace($UserSlot)) { 'client' } else { $UserSlot -replace '\\d+$','' }
$startIndex = if ([string]::IsNullOrWhiteSpace($UserSlot)) { $ClientIndex } else {
    if ($UserSlot -match '(\\d+)$') { [int]$Matches[1] } else { $ClientIndex }
}

& (Join-Path $PSScriptRoot 'start-clients.ps1') `
    -ProjectPath $ProjectPath `
    -GodotDir $GodotDir `
    -Count 1 `
    -StartIndex $startIndex `
    -UserSlotPrefix $prefix `
    -LogRoot $LogRoot `
    -UseConsoleClient:$UseConsoleClient `
    -Wait:$Wait
