# Run Battle DS locally (Godot headless, single instance)
# Usage: .\scripts\run-battle-ds-local.ps1 [-GodotPath <path>] [-Port <port>] [-BattleId <id>]
#
# For production use, ds_manager_service spawns battle_ds instances automatically.
# This script is for local development and debugging a single battle_ds.

param(
    [string]$GodotPath = (Join-Path $PSScriptRoot '..\godot_binary\Godot_console.exe'),
    [int]$Port = 19010,
    [string]$Host = '127.0.0.1',
    [string]$BattleId = 'battle_local_dev',
    [string]$AssignmentId = '',
    [string]$MatchId = '',
    [string]$TicketSecret = 'dev_battle_ticket_secret'
)

$projectRoot = Resolve-Path (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) '..')

Write-Host "[battle_ds] Starting Battle DS on ${Host}:${Port}"
Write-Host "[battle_ds] battle_id=$BattleId"
Write-Host "[battle_ds] Project root: $projectRoot"

& (Join-Path $projectRoot 'tools\native\build_native.ps1') -Target template_debug

& $GodotPath --headless --path "$projectRoot" `
    "res://scenes/network/dedicated_server_scene.tscn" `
    -- --qqt-port $Port --qqt-host $Host `
    --qqt-battle-id $BattleId `
    --qqt-assignment-id $AssignmentId `
    --qqt-match-id $MatchId `
    --qqt-battle-ticket-secret $TicketSecret
