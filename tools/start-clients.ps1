param(
    [ValidateSet('dev', 'test')]
    [string]$Profile = 'dev',
    [string]$ProjectPath = '',
    [string]$GodotDir = '',
    [int]$Count = 1,
    [int]$StartIndex = 1,
    [string]$UserSlotPrefix = 'client',
    [string]$LogRoot = '',
    [switch]$UseConsoleClient,
    [switch]$SkipDotnetBuild,
    [switch]$Wait
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib\dev_common.ps1')

if ($Count -le 0) {
    throw 'Count must be greater than 0.'
}
if ($StartIndex -le 0) {
    throw 'StartIndex must be greater than 0.'
}

$root = Resolve-QQTProjectRoot $ProjectPath
$clientExe = Resolve-QQTGodotExecutable -GodotDir $GodotDir -PreferConsole ([bool]$UseConsoleClient)

if (-not $SkipDotnetBuild) {
    $projectFile = Join-Path $root 'QQTang.csproj'
    if (Test-Path -LiteralPath $projectFile) {
        Write-Host 'Building QQTang C# project...'
        & dotnet build $projectFile
        if ($LASTEXITCODE -ne 0) {
            throw "dotnet build failed: $projectFile"
        }
    }
}

if ([string]::IsNullOrWhiteSpace($LogRoot)) {
    $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $LogRoot = Join-Path $root (Join-Path 'logs' "clients_${Profile}_$timestamp")
}
New-Item -ItemType Directory -Force -Path $LogRoot | Out-Null

$processes = @()
for ($offset = 0; $offset -lt $Count; $offset++) {
    $index = $StartIndex + $offset
    $slot = "${UserSlotPrefix}${index}"
    $logPath = Join-Path $LogRoot "$slot.godot.log"
    $args = @(
        '--log-file', $logPath,
        '--path', $root,
        '--',
        '--qqt-user-slot', $slot
    )

    Write-Host "Starting $slot"
    $proc = Start-Process -FilePath $clientExe -ArgumentList $args -WorkingDirectory $root -PassThru
    $processes += [PSCustomObject]@{ Slot = $slot; Process = $proc; Log = $logPath }

    if ($offset -lt ($Count - 1)) {
        Start-Sleep -Milliseconds 300
    }
}

$summaryPath = Join-Path $LogRoot 'clients_processes.txt'
$summary = @()
$summary += "StartedAt: $(Get-Date -Format s)"
$summary += "Profile: $Profile"
$summary += "ProjectPath: $root"
$summary += "ClientExe: $clientExe"
$summary += "LogRoot: $LogRoot"
$summary += ''
foreach ($entry in $processes) {
    $summary += "Slot=$($entry.Slot) PID=$($entry.Process.Id) Log=$($entry.Log)"
}
$summary | Set-Content -LiteralPath $summaryPath -Encoding UTF8

Write-Host "Started $($processes.Count) client(s)."
Write-Host "Summary: $summaryPath"

if ($Wait) {
    $processes.Process | Wait-Process
}
