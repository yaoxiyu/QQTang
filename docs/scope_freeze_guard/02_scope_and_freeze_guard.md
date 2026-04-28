# Scope freeze Scope And Freeze Guard

## Purpose

Scope freeze only implements the player asset, wallet, shop, purchase, front UI resource, and async loading foundation.

The implementation must keep matchmaking, room authority semantics, battle runtime, battle simulation, battle sync, DS authority, gameplay rules, and settlement semantics unchanged.

## Allowed Scope

- Account Service wallet, inventory, shop catalog, purchase transaction, and loadout ownership validation.
- Client front wallet, inventory, shop, UI resource, loading state, gateway, use case, and ViewModel layers.
- Content source and generated runtime catalog for economy, shop, and UI assets.
- Login, lobby, room, shop, inventory, loading, and Battle HUD presentation formalization.
- Battle HUD resource binding only, using existing presentation state or existing runtime snapshots.
- Project guard, contract tests, and Scope freeze acceptance documentation.

## Frozen Scope

- Matchmaking queue, assignment, allocation, party queue, match format semantics, and matching proto contracts.
- Battle simulation, tick runner, rollback, prediction, resync, transport, sync channel, DS authority loop, gameplay rules, item rules, collision, explosion, win condition, settlement semantics, and battle proto contracts.
- Room FSM and room protocol semantics, except read-only UI projection that does not alter authority behavior.
- Map, ruleset, and match format gameplay truth.

## Authoritative Boundary

Account Service is authoritative for:

- Profile.
- Default loadout ownership validation.
- Inventory ownership.
- Wallet balances.
- Shop purchases.
- Wallet ledger entries.
- Purchase orders.
- Purchase grants.

Client front code may request, cache, display, preview, and bind state. It must not locally deduct wallet balances, grant owned assets, or bypass Account Service loadout validation.

## Implementation Order

1. Scope guard and task tracker.
2. API, DB, CSV, and UI asset contracts.
3. Account Service wallet, inventory, shop, and purchase transaction.
4. Client state, gateway, and use case layers.
5. UI asset catalog and resolver.
6. Shop, inventory, lobby, room, loading, and HUD presentation integration.
7. Async loading task progress.
8. Contract tests, performance checks, and denylist validation.

## Required Local Checks

Use the guard before review:

```powershell
python tools/project_guard/forbidden_paths_guard.py --base <base_branch>
```

For ad-hoc path checks:

```powershell
python tools/project_guard/forbidden_paths_guard.py --paths services/game_service/internal/queue/example.go
```

For GDScript pipelines or GDScript tests, run syntax preflight first:

```powershell
powershell -ExecutionPolicy Bypass -File tests/scripts/check_gdscript_syntax.ps1
```

If syntax preflight reports parse or load errors, stop and fix syntax before running pipeline or tests.

## Review Gate

A Scope freeze change is blocked if `git diff --name-only <base_branch>...HEAD` contains a forbidden path and there is no explicit approved exception record.

