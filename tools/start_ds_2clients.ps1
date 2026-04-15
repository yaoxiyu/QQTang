param(
    [string]$GodotDir = '',
    [string]$ProjectPath = '',
    [int]$ClientCount = 2,
    [switch]$UseConsoleClients,
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

$script:ResolvedProjectPath = Resolve-ProjectPath $ProjectPath
$clientExe = Resolve-GodotExecutable $GodotDir ([bool]$UseConsoleClients)

$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$runRoot = Join-Path $script:ResolvedProjectPath (Join-Path 'logs' "clients_$timestamp")
New-Item -ItemType Directory -Force -Path $runRoot | Out-Null

$processes = @()

for ($i = 1; $i -le $ClientCount; $i++) {
    $clientArgs = @(
        '--log-file', (Join-Path $runRoot "client$i.godot.log"),
        '--path', $script:ResolvedProjectPath,
        '--',
        '--qqt-user-slot', "client$i"
    )

    Write-Host "Starting Client$i"
    Write-Host "  Exe: $clientExe"
    Write-Host "  Args: $($clientArgs -join ' ')"

    $processes += Start-Process `
        -FilePath $clientExe `
        -ArgumentList $clientArgs `
        -WorkingDirectory $script:ResolvedProjectPath `
        -PassThru

    if ($i -lt $ClientCount) {
        Start-Sleep -Milliseconds 400
    }
}

$summaryPath = Join-Path $runRoot 'processes.txt'
$summaryLines = @()
$summaryLines += "StartedAt: $(Get-Date -Format s)"
$summaryLines += "ProjectPath: $script:ResolvedProjectPath"
$summaryLines += "GodotDir: $GodotDir"
$summaryLines += "ClientExe: $clientExe"
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
Write-Host "Started $($processes.Count) client(s)."
Write-Host "Log directory: $runRoot"
Write-Host "Process summary: $summaryPath"

if ($Wait) {
    Write-Host 'Waiting for launched processes to exit...'
    $processes | Wait-Process
}
