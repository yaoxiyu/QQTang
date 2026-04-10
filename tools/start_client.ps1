param(
    [string]$GodotDir = 'F:\Godot',
    [string]$ProjectPath = '',
    [int]$ClientIndex = 1,
    [string]$UserSlot = '',
    [string]$LogRoot = '',
    [switch]$UseConsoleClient,
    [switch]$Wait
)

$ErrorActionPreference = 'Stop'

function Resolve-ProjectPath {
    param([string]$InputPath)

    if (-not [string]::IsNullOrWhiteSpace($InputPath)) {
        return (Resolve-Path -LiteralPath $InputPath).Path
    }

    $scriptRoot = Split-Path -Parent $PSCommandPath
    return (Resolve-Path -LiteralPath (Join-Path $scriptRoot '..')).Path
}

function Resolve-GodotExecutable {
    param(
        [string]$Directory,
        [bool]$PreferConsole
    )

    $consolePath = Join-Path $Directory 'Godot_console.exe'
    $guiPath = Join-Path $Directory 'Godot.exe'

    if ($PreferConsole -and (Test-Path -LiteralPath $consolePath)) {
        return $consolePath
    }
    if ((-not $PreferConsole) -and (Test-Path -LiteralPath $guiPath)) {
        return $guiPath
    }
    if (Test-Path -LiteralPath $consolePath) {
        return $consolePath
    }
    if (Test-Path -LiteralPath $guiPath) {
        return $guiPath
    }

    throw "Godot executable not found under: $Directory"
}

function Resolve-UserSlot {
    param(
        [string]$InputSlot,
        [int]$Index
    )

    if (-not [string]::IsNullOrWhiteSpace($InputSlot)) {
        return $InputSlot.Trim()
    }
    if ($Index -le 0) {
        throw 'ClientIndex must be greater than 0 when UserSlot is omitted.'
    }
    return "client$Index"
}

$resolvedProjectPath = Resolve-ProjectPath $ProjectPath
$clientExe = Resolve-GodotExecutable $GodotDir ([bool]$UseConsoleClient)
$resolvedSlot = Resolve-UserSlot $UserSlot $ClientIndex

if ([string]::IsNullOrWhiteSpace($LogRoot)) {
    $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $LogRoot = Join-Path $resolvedProjectPath (Join-Path 'logs' "single_client_$($resolvedSlot)_$timestamp")
}
$resolvedLogRoot = $LogRoot
New-Item -ItemType Directory -Force -Path $resolvedLogRoot | Out-Null

$logPath = Join-Path $resolvedLogRoot "$resolvedSlot.godot.log"
$clientArgs = @(
    '--log-file', $logPath,
    '--path', $resolvedProjectPath,
    '--',
    '--qqt-user-slot', $resolvedSlot
)

Write-Host "Starting client"
Write-Host "  Exe: $clientExe"
Write-Host "  Project: $resolvedProjectPath"
Write-Host "  UserSlot: $resolvedSlot"
Write-Host "  Args: $($clientArgs -join ' ')"
Write-Host "  Log: $logPath"

$process = Start-Process `
    -FilePath $clientExe `
    -ArgumentList $clientArgs `
    -WorkingDirectory $resolvedProjectPath `
    -PassThru

$summaryPath = Join-Path $resolvedLogRoot 'process.txt'
@(
    "StartedAt: $(Get-Date -Format s)",
    "ProjectPath: $resolvedProjectPath",
    "GodotDir: $GodotDir",
    "ClientExe: $clientExe",
    "UserSlot: $resolvedSlot",
    "PID $($process.Id): $($process.ProcessName)",
    "Log: $logPath",
    "Restart args: --log-file `"$logPath`" --path `"$resolvedProjectPath`" -- --qqt-user-slot $resolvedSlot"
) | Set-Content -LiteralPath $summaryPath -Encoding UTF8

Write-Host "Process summary: $summaryPath"

if ($Wait) {
    Wait-Process -Id $process.Id
}
