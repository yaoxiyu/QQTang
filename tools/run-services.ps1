param(
    [ValidateSet('dev', 'test')]
    [string]$Profile = 'dev',
    [string]$ProjectPath = '',
    [string]$PowerShellExe = 'powershell',
    [switch]$SkipDb,
    [switch]$SkipMigration,
    [switch]$LogSQL,
    [string]$GodotExecutable = (Join-Path $PSScriptRoot '..\external\godot_binary\Godot.exe'),
    [string]$DSMContainerGodotExecutable = 'external/godot_binary/Godot.exe',
    [int]$DSMPortRangeStart = 19010,
    [int]$DSMPortRangeEnd = 19050,
    [string]$LogDir = '',
    [switch]$SkipDSPoolCleanup,
    [switch]$SkipNativeBuild,
    [switch]$SkipBattleDSImageBuild,
    [switch]$SkipBuild,
    [switch]$ForceBuild
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib\dev_common.ps1')

$root = Resolve-QQTProjectRoot $ProjectPath
$cfg = Get-QQTProfileConfig -Profile $Profile -Root $root
$composeFile = Join-Path $root ("deploy\docker\docker-compose.services.{0}.yml" -f $Profile)
if (-not (Test-Path -LiteralPath $composeFile)) {
    throw "Service compose file not found: $composeFile"
}

$cacheRoot = Join-Path $root (Join-Path 'build' (Join-Path '.run-services-cache' $Profile))
New-Item -ItemType Directory -Force -Path $cacheRoot | Out-Null
$progressActivity = "run-services:$Profile"
$progressTotal = 8
$progressStep = 1

if (-not $SkipDb) {
    Invoke-QQTProgressStep -Activity $progressActivity -Step $progressStep -Total $progressTotal -Name 'db-up' -Action {
        & (Join-Path $PSScriptRoot 'db-up.ps1') -Profile $Profile -ProjectPath $root
    }
}
$progressStep++
if (-not $SkipMigration) {
    Invoke-QQTProgressStep -Activity $progressActivity -Step $progressStep -Total $progressTotal -Name 'db-migrate' -Action {
        & (Join-Path $PSScriptRoot 'db-migrate.ps1') -Profile $Profile -ProjectPath $root -SkipDbUp
    }
}
$progressStep++
if (-not $SkipBuild -and -not $SkipNativeBuild) {
    $nativeInputs = @(
        'addons\qqt_native\SConstruct',
        'addons\qqt_native\src',
        'addons\qqt_native\qqt_native.gdextension',
        'addons\qqt_native\third_party\godot-cpp\binding_generator.py',
        'addons\qqt_native\third_party\godot-cpp\SConstruct',
        'addons\qqt_native\third_party\godot-cpp\godot-headers',
        'addons\qqt_native\third_party\godot-cpp\include',
        'addons\qqt_native\third_party\godot-cpp\src'
    )
    Invoke-QQTIncrementalStep `
        -Root $root `
        -CacheRoot $cacheRoot `
        -Name 'native_windows_template_debug' `
        -IncludePaths $nativeInputs `
        -OutputPaths @('addons\qqt_native\bin\qqt_native.windows.template_debug.x86_64.dll') `
        -Force:$ForceBuild `
        -Activity $progressActivity `
        -Step $progressStep `
        -Total $progressTotal `
        -Action { & (Join-Path $root 'tools\native\build_native.ps1') -Target template_debug } | Out-Null
    $progressStep++
    Invoke-QQTIncrementalStep `
        -Root $root `
        -CacheRoot $cacheRoot `
        -Name 'native_windows_template_release' `
        -IncludePaths $nativeInputs `
        -OutputPaths @('addons\qqt_native\bin\qqt_native.windows.template_release.x86_64.dll') `
        -Force:$ForceBuild `
        -Activity $progressActivity `
        -Step $progressStep `
        -Total $progressTotal `
        -Action { & (Join-Path $root 'tools\native\build_native.ps1') -Target template_release } | Out-Null
} else {
    $progressStep += 2
}
$progressStep++
Invoke-QQTProgressStep -Activity $progressActivity -Step $progressStep -Total $progressTotal -Name 'gdscript syntax preflight' -Action {
    & (Join-Path $root 'tests\scripts\check_gdscript_syntax.ps1')
}
$progressStep++
Invoke-QQTIncrementalStep `
    -Root $root `
    -CacheRoot $cacheRoot `
    -Name 'room_manifest' `
    -IncludePaths @(
        'content\maps',
        'content\modes',
        'content\rulesets',
        'content\match_formats',
        'content\characters',
        'content\character_skins',
        'content\bubbles',
        'content\bubble_skins',
        'tools\content_pipeline\generators\generate_room_manifest.gd',
        'scripts\content\generate_room_manifest.ps1'
    ) `
    -OutputPaths @('build\generated\room_manifest\room_manifest.json') `
    -Force:$ForceBuild `
    -Activity $progressActivity `
    -Step $progressStep `
    -Total $progressTotal `
    -Action { & (Join-Path $root 'scripts\content\generate_room_manifest.ps1') -ProjectPath $root -GodotExecutable $GodotExecutable } | Out-Null
$progressStep++

if ($Profile -eq 'dev' -and -not $SkipBuild -and -not $SkipBattleDSImageBuild) {
    Invoke-QQTIncrementalStep `
        -Root $root `
        -CacheRoot $cacheRoot `
        -Name 'battle_ds_image' `
        -IncludePaths @(
            'external\qqt_native\bin\qqt_native.linux.template_release.x86_64.so',
            'app',
            'content',
            'gameplay',
            'network',
            'presentation',
            'scenes',
            'services\ds_agent',
            'scripts\docker',
            'project.godot'
        ) `
        -ExcludePathParts @(
            '\.godot\',
            '\build\',
            '\logs\',
            '\tests\reports\'
        ) `
        -OutputPaths @(
            'build\docker\battle_ds\qqtang_battle_ds.x86_64',
            'build\docker\battle_ds\qqtang_battle_ds.pck',
            'build\docker\battle_ds\qqt_native.linux.template_release.x86_64.so'
        ) `
        -Force:$ForceBuild `
        -Activity $progressActivity `
        -Step $progressStep `
        -Total $progressTotal `
        -Action { & (Join-Path $root 'scripts\docker\prepare_battle_ds_image.ps1') -GodotExe $GodotExecutable } | Out-Null
}
$progressStep++

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

$serviceImageFingerprint = Get-QQTFileFingerprint `
    -Root $root `
    -IncludePaths @(
        $composeFile,
        'build\generated\room_manifest\room_manifest.json',
        'services\account_service',
        'services\game_service',
        'services\ds_manager_service',
        'services\room_service',
        'services\shared\contentmanifest'
    ) `
    -ExcludePathParts @(
        '\.git\',
        '\logs\',
        '\tests\reports\'
    )
$serviceImageStampPath = Join-Path $cacheRoot 'compose_service_images.sha256'
$previousServiceImageFingerprint = ''
if (Test-Path -LiteralPath $serviceImageStampPath -PathType Leaf) {
    $previousServiceImageFingerprint = (Get-Content -LiteralPath $serviceImageStampPath -Raw).Trim()
}
$shouldBuildServiceImages = $ForceBuild -or ($previousServiceImageFingerprint -ne $serviceImageFingerprint)
$composeArgs = @('compose', '-f', $composeFile, 'up', '-d')
if ($shouldBuildServiceImages -and -not $SkipBuild) {
    Write-Host "[run-services] docker compose service images changed; using --build"
    $composeArgs += '--build'
} else {
    Write-Host "[run-services] docker compose service images unchanged; starting without --build"
}

Invoke-QQTProgressStep -Activity $progressActivity -Step $progressStep -Total $progressTotal -Name 'docker compose up' -Action {
    docker @composeArgs
}
if ($LASTEXITCODE -ne 0) {
    if (-not $shouldBuildServiceImages -and -not $SkipBuild) {
        Write-Host "[run-services] docker compose start failed without build; retrying with --build"
        Invoke-QQTProgressStep -Activity $progressActivity -Step $progressStep -Total $progressTotal -Name 'docker compose up --build retry' -Action {
            docker compose -f $composeFile up -d --build
        }
    }
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to start QQTang services through Docker Compose: $composeFile"
    }
}
Set-Content -LiteralPath $serviceImageStampPath -Value $serviceImageFingerprint -Encoding ASCII
Write-QQTProgress -Activity $progressActivity -Completed

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
