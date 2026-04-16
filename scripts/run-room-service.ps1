# Run Room Service (Godot headless)
# Usage: .\scripts\run-room-service.ps1 [-GodotPath <path>] [-Port <port>] [-ListenHost <host>]

param(
    [string]$GodotPath = 'godot4',
    [int]$Port = 9000,
    [string]$ListenHost = '127.0.0.1',
    [string]$TicketSecret = 'dev_room_ticket_secret'
)

$projectRoot = Resolve-Path (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) '..')

Write-Host "[room_service] Starting Room Service on ${ListenHost}:${Port}"
Write-Host "[room_service] Project root: $projectRoot"

& $GodotPath --headless --path "$projectRoot" `
    "res://scenes/network/room_service_scene.tscn" `
    -- --qqt-room-port $Port --qqt-room-host $ListenHost --qqt-room-ticket-secret $TicketSecret
