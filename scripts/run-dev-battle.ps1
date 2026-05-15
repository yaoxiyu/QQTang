# Quick launch dev battle for rapid iteration.
# Supports two modes:
#   local       - Single-process local loopback (fastest, for gameplay iteration)
#   ds_client   - Two-process DS + client (for network logic testing)
#
# Usage:
#   .\scripts\run-dev-battle.ps1                    # Default: local mode, 2 players
#   .\scripts\run-dev-battle.ps1 -Mode local        # Single process, 2 players
#   .\scripts\run-dev-battle.ps1 -Mode ds_client    # DS + client, 2 players
#   .\scripts\run-dev-battle.ps1 -PlayerCount 4     # 4 players (1 human + 3 AI)

param(
    [ValidateSet("local", "ds_client")]
    [string]$Mode = "local",

    [int]$PlayerCount = 2,

    [string]$GodotPath = "",

    [int]$DsPort = 19010,

    [string]$DsHost = "127.0.0.1",

    [string]$MapId = "",

    [string]$RuleSetId = "",

    [switch]$SkipBuild = $false
)

$ErrorActionPreference = "Stop"
$projectRoot = Resolve-Path (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "..")
$projectLogDir = Join-Path $projectRoot "logs"
if (-not (Test-Path $projectLogDir)) {
    New-Item -ItemType Directory -Path $projectLogDir -Force | Out-Null
}

if ($GodotPath -eq "") {
    $GodotPath = Join-Path $projectRoot "external\godot_binary\Godot.exe"
}

if (-not (Test-Path $GodotPath)) {
    Write-Error "Godot.exe not found at: $GodotPath"
    Write-Error "Specify with -GodotPath or ensure it exists at external/godot_binary/Godot.exe"
    exit 1
}

# Build native extensions
if (-not $SkipBuild) {
    Write-Host "[run-dev-battle] Building native extensions..." -ForegroundColor Cyan
    $nativeBuild = Join-Path $projectRoot "tools\native\build_native.ps1"
    if (Test-Path $nativeBuild) {
        & $nativeBuild -Target template_debug
        & $nativeBuild -Target template_release
    }
    Write-Host "[run-dev-battle] Native build complete." -ForegroundColor Cyan
}

# Build Godot extra args from optional params
$extraArgs = @()
if ($MapId -ne "") {
    $extraArgs += "--qqt-dev-launcher-map-id=$MapId"
}
if ($RuleSetId -ne "") {
    $extraArgs += "--qqt-dev-launcher-rule-set-id=$RuleSetId"
}

Write-Host "============================================================" -ForegroundColor Green
Write-Host "[run-dev-battle] Mode: $Mode" -ForegroundColor Green
Write-Host "[run-dev-battle] Player Count: $PlayerCount" -ForegroundColor Green
Write-Host "[run-dev-battle] Godot: $GodotPath" -ForegroundColor Green
Write-Host "[run-dev-battle] Project: $projectRoot" -ForegroundColor Green
Write-Host "[run-dev-battle] Logs: $projectLogDir" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green

$previousLogDir = $env:QQT_LOG_DIR
$env:QQT_LOG_DIR = $projectLogDir

try {
    switch ($Mode) {
        "local" {
            Write-Host "[run-dev-battle] Starting local loopback battle..." -ForegroundColor Green
            Write-Host "[run-dev-battle] Controls: Arrow keys = move, Space = place bomb" -ForegroundColor Green
            Write-Host "[run-dev-battle] Debug: F3=toggle debug, O=toggle AI debug input, J=latency, K=loss" -ForegroundColor Green

            $launcherArgs = @(
                "--path", $projectRoot,
                "res://scenes/dev/dev_battle_launcher.tscn",
                "--",
                "--qqt-dev-launcher-player-count=$PlayerCount"
            ) + $extraArgs

            & cmd /c "`"$GodotPath`" $launcherArgs 2>&1"
        }

        "ds_client" {
            # Shared dev battle ID so DS and client agree on the same battle.
            $devBattleId = "dev_battle_$([System.Random]::new().Next(10000, 99999))"

            Write-Host "[run-dev-battle] Starting DS (dev mode) on ${DsHost}:${DsPort} battle_id=$devBattleId..." -ForegroundColor Green

            $dsArgs = @(
                "--headless",
                "--path", $projectRoot,
                "res://scenes/network/dedicated_server_scene.tscn",
                "--",
                "--qqt-ds-port", $DsPort,
                "--qqt-ds-host", $DsHost,
                "--qqt-battle-id", $devBattleId,
                "--qqt-dev-mode",
                "--qqt-dev-player-count=$PlayerCount"
            )
            if ($MapId -ne "") {
                $dsArgs += "--qqt-dev-map-id=$MapId"
            }
            if ($RuleSetId -ne "") {
                $dsArgs += "--qqt-dev-rule-set-id=$RuleSetId"
            }

            $dsProcess = Start-Process -FilePath $GodotPath -ArgumentList $dsArgs -PassThru -NoNewWindow

            Write-Host "[run-dev-battle] DS process started (PID=$($dsProcess.Id)). Waiting for DS to be ready..." -ForegroundColor Green
            Start-Sleep -Seconds 3

            Write-Host "[run-dev-battle] Starting client connecting to ${DsHost}:${DsPort}..." -ForegroundColor Green
            Write-Host "[run-dev-battle] Controls: Arrow keys = move, Space = place bomb" -ForegroundColor Green
            Write-Host "[run-dev-battle] Debug: F3=toggle debug, J=latency, K=loss, L=force rollback" -ForegroundColor Green

            $clientArgs = @(
                "--path", $projectRoot,
                "res://scenes/dev/dev_battle_launcher.tscn",
                "--",
                "--qqt-dev-launcher-ds-addr=$DsHost",
                "--qqt-dev-launcher-ds-port=$DsPort",
                "--qqt-dev-launcher-battle-id=$devBattleId",
                "--qqt-dev-launcher-player-count=$PlayerCount"
            ) + $extraArgs

            & cmd /c "`"$GodotPath`" $clientArgs 2>&1"

            Write-Host "[run-dev-battle] Client exited. Stopping DS..." -ForegroundColor Yellow
            if (-not $dsProcess.HasExited) {
                Stop-Process -Id $dsProcess.Id -ErrorAction SilentlyContinue
                if (-not $dsProcess.WaitForExit(3000)) {
                    Stop-Process -Id $dsProcess.Id -Force -ErrorAction SilentlyContinue
                }
            }
            Write-Host "[run-dev-battle] Done." -ForegroundColor Green
        }
    }
}
finally {
    if ($null -eq $previousLogDir) {
        Remove-Item Env:QQT_LOG_DIR -ErrorAction SilentlyContinue
    } else {
        $env:QQT_LOG_DIR = $previousLogDir
    }
}
