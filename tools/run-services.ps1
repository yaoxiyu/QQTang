param(
    [ValidateSet('dev', 'test')]
    [string]$Profile = 'dev',
    [string]$ProjectPath = '',
    [string]$PowerShellExe = 'powershell',
    [switch]$SkipDb,
    [switch]$SkipMigration,
    [switch]$LogSQL,
    [string]$GodotExecutable = (Join-Path $PSScriptRoot '..\godot_binary\Godot_console.exe'),
    [string]$DSMContainerGodotExecutable = 'godot4',
    [int]$DSMPortRangeStart = 19010,
    [int]$DSMPortRangeEnd = 19050,
    [string]$LogDir = '',
    [switch]$SkipDSPoolCleanup,
    [switch]$SkipNativeBuild,
    [switch]$SkipBattleDSImageBuild
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib\dev_common.ps1')

$root = Resolve-QQTProjectRoot $ProjectPath
$cfg = Get-QQTProfileConfig -Profile $Profile -Root $root
$composeFile = Join-Path $root ("deploy\docker\docker-compose.services.{0}.yml" -f $Profile)
if (-not (Test-Path -LiteralPath $composeFile)) {
    throw "Service compose file not found: $composeFile"
}

if (-not $SkipDb) {
    & (Join-Path $PSScriptRoot 'db-up.ps1') -Profile $Profile -ProjectPath $root
}
if (-not $SkipMigration) {
    & (Join-Path $PSScriptRoot 'db-migrate.ps1') -Profile $Profile -ProjectPath $root -SkipDbUp
}
if (-not $SkipNativeBuild) {
    & (Join-Path $root 'tools\native\build_native.ps1') -Target template_debug
    & (Join-Path $root 'tools\native\build_native.ps1') -Target template_release
}
& (Join-Path $root 'tests\scripts\check_gdscript_syntax.ps1')
& (Join-Path $root 'scripts\content\generate_room_manifest.ps1') -ProjectPath $root -GodotExecutable $GodotExecutable

if ($Profile -eq 'dev' -and -not $SkipBattleDSImageBuild) {
    & (Join-Path $root 'scripts\docker\prepare_battle_ds_image.ps1') -GodotExe $GodotExecutable
}

if ([string]::IsNullOrWhiteSpace($LogDir)) {
    $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $LogDir = Join-Path $root (Join-Path 'logs' "services_${Profile}_$timestamp")
}
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null

$env:QQT_LOG_SQL = if ($LogSQL) { 'true' } else { 'false' }
$env:QQT_DSM_GODOT_EXECUTABLE = $DSMContainerGodotExecutable
$env:QQT_DSM_PORT_RANGE_START = [string]$DSMPortRangeStart
$env:QQT_DSM_PORT_RANGE_END = [string]$DSMPortRangeEnd

if (-not $SkipDSPoolCleanup) {
    $poolID = "qqtang_services_$Profile"
    $dsContainers = @(
        docker ps -aq `
            --filter "label=qqt.component=battle_ds" `
            --filter "label=qqt.managed_by=ds_manager_service" `
            --filter "label=qqt.pool_id=$poolID"
    )
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to list managed battle DS containers for pool: $poolID"
    }
    if ($dsContainers.Count -gt 0) {
        Write-Host "Removing stale managed battle DS containers for pool=$poolID ..."
        docker rm -f $dsContainers | Out-Host
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to remove stale managed battle DS containers for pool: $poolID"
        }
    }
}

docker compose -f $composeFile up -d --build
if ($LASTEXITCODE -ne 0) {
    throw "Failed to start QQTang services through Docker Compose: $composeFile"
}

$logFile = Join-Path $LogDir 'docker-compose.ps1'
"docker compose -f `"$composeFile`" logs -f" | Set-Content -LiteralPath $logFile -Encoding UTF8

Write-Host "Started QQTang service containers (profile=$Profile)"
Write-Host "  account_service:    http://$($cfg.Account.ListenAddr)"
Write-Host "  game_service:       http://$($cfg.Game.ListenAddr)"
Write-Host "  ds_manager_service: http://$($cfg.DSM.ListenAddr)"
Write-Host "  room_service:       $($cfg.Room.Host):$($cfg.Room.Port)"
Write-Host "DB containers are still managed by tools/db-up.ps1."
Write-Host "Logs: docker compose -f `"$composeFile`" logs -f"
Write-Host "Log helper: $logFile"
