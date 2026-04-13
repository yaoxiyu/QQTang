param(
    [string]$GodotDir = '',
    [string]$ProjectPath = '',
    [int]$ClientCount = 2,
    [int]$ServerPort = 9000,
    [string]$RoomTicketSecret = 'dev_room_ticket_secret',
    [switch]$UseConsoleClients,
    [switch]$NoHeadlessServer,
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

    if ([string]::IsNullOrWhiteSpace($Directory)) {
        if ($PreferConsole) {
            return 'Godot_console.exe'
        }
        return 'Godot.exe'
    }

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

function Start-GodotRole {
    param(
        [string]$Name,
        [string]$ExePath,
        [string[]]$Arguments,
        [string]$LogPath
    )

    Write-Host "Starting $Name"
    Write-Host "  Exe: $ExePath"
    Write-Host "  Args: $($Arguments -join ' ')"
    Write-Host "  Log: $LogPath"

    return Start-Process `
        -FilePath $ExePath `
        -ArgumentList $Arguments `
        -WorkingDirectory $script:ResolvedProjectPath `
        -PassThru
}

$script:ResolvedProjectPath = Resolve-ProjectPath $ProjectPath
$serverExe = Resolve-GodotExecutable $GodotDir $true
$clientExe = Resolve-GodotExecutable $GodotDir ([bool]$UseConsoleClients)

$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$runRoot = Join-Path $script:ResolvedProjectPath (Join-Path 'logs' "local_ds_2clients_$timestamp")
New-Item -ItemType Directory -Force -Path $runRoot | Out-Null

$processes = @()

$serverArgs = @(
    '--headless',
    '--log-file', (Join-Path $runRoot 'ds.godot.log'),
    '--path', $script:ResolvedProjectPath
)
if ($NoHeadlessServer) {
    $serverArgs = @(
        '--log-file', (Join-Path $runRoot 'ds.godot.log'),
        '--path', $script:ResolvedProjectPath
    )
}
$serverArgs += 'res://scenes/network/dedicated_server_scene.tscn'
$serverArgs += '--'
$serverArgs += '--qqt-ds-port'
$serverArgs += $ServerPort.ToString()
$serverArgs += '--qqt-ds-room-ticket-secret'
$serverArgs += $RoomTicketSecret

$processes += Start-GodotRole `
    -Name 'DedicatedServer' `
    -ExePath $serverExe `
    -Arguments $serverArgs `
    -LogPath (Join-Path $runRoot 'ds.godot.log')

$serverReady = $false
for ($attempt = 1; $attempt -le 20; $attempt++) {
    Start-Sleep -Milliseconds 250
    $listener = Get-NetUDPEndpoint -LocalPort $ServerPort -ErrorAction SilentlyContinue
    if ($listener -ne $null) {
        $serverReady = $true
        break
    }
    if ($processes[0].HasExited) {
        break
    }
}

if (-not $serverReady) {
    Write-Warning "Dedicated server did not open UDP port $ServerPort. Check ds.godot.log under $runRoot."
}

for ($i = 1; $i -le $ClientCount; $i++) {
    $clientArgs = @(
        '--log-file', (Join-Path $runRoot "client$i.godot.log"),
        '--path', $script:ResolvedProjectPath,
        '--',
        '--qqt-user-slot', "client$i"
    )

    $processes += Start-GodotRole `
        -Name "Client$i" `
        -ExePath $clientExe `
        -Arguments $clientArgs `
        -LogPath (Join-Path $runRoot "client$i.godot.log")

    Start-Sleep -Milliseconds 400
}

$summaryPath = Join-Path $runRoot 'processes.txt'
$summaryLines = @()
$summaryLines += "StartedAt: $(Get-Date -Format s)"
$summaryLines += "ProjectPath: $script:ResolvedProjectPath"
$summaryLines += "GodotDir: $GodotDir"
$summaryLines += "ServerExe: $serverExe"
$summaryLines += "ClientExe: $clientExe"
$summaryLines += "ServerPort: $ServerPort"
$summaryLines += "RoomTicketSecret: $RoomTicketSecret"
$summaryLines += "ServerPortListening: $serverReady"
$summaryLines += "RunRoot: $runRoot"
$summaryLines += ''
foreach ($process in $processes) {
    $summaryLines += "PID $($process.Id): $($process.ProcessName)"
}
$summaryLines += ''
for ($i = 1; $i -le $ClientCount; $i++) {
    $summaryLines += "Restart Client$i args: --log-file `"$($runRoot)\client$i.reconnect.godot.log`" --path `"$script:ResolvedProjectPath`" -- --qqt-user-slot client$i"
}
$summaryLines | Set-Content -LiteralPath $summaryPath -Encoding UTF8

Write-Host ''
Write-Host "Started $($processes.Count) process(es)."
Write-Host "Log directory: $runRoot"
Write-Host "Process summary: $summaryPath"
Write-Host "Server UDP port $ServerPort listening: $serverReady"
Write-Host ''
Write-Host 'To stop them later, close the Godot windows and stop the DS console process from Task Manager if needed.'

if ($Wait) {
    Write-Host 'Waiting for launched processes to exit...'
    $processes | Wait-Process
}
