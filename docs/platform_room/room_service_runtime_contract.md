# Room Service Runtime Contract

## Scope

This document defines the runtime contract for `room_service`, the standalone Godot headless process that manages room lifecycle.

Phase23 separates `room_service` from `battle_ds`:

- `room_service` handles room create, join, leave, resume, snapshot broadcast.
- `battle_ds` handles battle execution only.

## Process Identity

- Scene: `res://scenes/network/room_service_scene.tscn`
- Bootstrap: `res://network/runtime/room_service_bootstrap.gd`
- Transport: ENet via `ENetBattleTransport`
- Default listen port: `9100`

## Command-Line Arguments

| Argument | Description |
|---|---|
| `--qqt-room-port <port>` | Override listen port (default 9100) |
| `--qqt-room-host <host>` | Override authority host (default 127.0.0.1) |
| `--qqt-room-ticket-secret <secret>` | Override room ticket verification secret |

## Runtime Architecture

```text
room_service_bootstrap.gd
  ├── ServerRoomRegistry
  │     ├── Room create/join/resume routing
  │     ├── Room snapshot broadcast
  │     └── Peer disconnect handling
  └── ENetBattleTransport
        ├── Server-mode ENet listener
        └── Message poll + dispatch
```

## Responsibilities

### Room Lifecycle

- Create room from room-entry ticket (`purpose = create`).
- Join room from room-entry ticket (`purpose = join`).
- Resume room from room-entry ticket (`purpose = resume`).
- Room snapshot authoritative broadcast to connected peers.
- Handle peer disconnect: member session expiry, reconnect window.
- Room idle lifecycle: awaiting members, ready check, queue entry.

### NOT Room Service Responsibilities

- Battle execution (belongs to `battle_ds`).
- Battle ticket verification (belongs to `battle_ds`).
- Battle input routing (belongs to `battle_ds`).
- Battle finalize (belongs to `battle_ds` -> `game_service`).
- Match loading barrier coordination (belongs to `battle_ds`).

## Room Snapshot Phase23 Fields

`room_service` broadcasts `RoomSnapshot` to connected peers. Phase23 adds:

| Field | Type | Description |
|---|---|---|
| `room_lifecycle_state` | String | Current room lifecycle state |
| `current_assignment_id` | String | Assignment ID when battle is allocated |
| `current_battle_id` | String | Battle instance ID |
| `battle_allocation_state` | String | One of: idle, assigned, allocating, battle_ready, in_battle, finalized |
| `battle_server_host` | String | Battle DS host (empty when no battle allocated) |
| `battle_server_port` | int | Battle DS port (0 when no battle allocated) |
| `room_return_policy` | String | Default `return_to_source_room` |
| `battle_entry_ready` | bool | True when battle DS is ready and clients should enter loading |

## Client Interaction

1. Client connects to `room_service` via ENet with room-entry ticket.
2. `room_service` verifies ticket and creates/joins/resumes room.
3. `room_service` broadcasts `RoomSnapshot` on state changes.
4. When `RoomSnapshot.battle_entry_ready == true`, client transitions to loading scene and acquires a battle ticket from `account_service`.
5. Client connects to `battle_ds` using the battle ticket. This is a separate connection from the room_service connection.
6. After battle settlement, client returns to `room_service` using source room resume flow.

## Ticket Consumption

- `room_service` only consumes room-purpose tickets: `create`, `join`, `resume`.
- `room_service` must reject `battle_entry` purpose tickets.
- Room ticket verification uses `room_ticket_secret` shared with `account_service`.
