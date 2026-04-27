# Task Backlog

Status values: `Not Started`, `Ready`, `In Progress`, `Blocked`, `Review`, `Accepted`, `Deferred`.

| Task ID | Milestone | Priority | Status | Title | Dependency | Acceptance | Scope Guard |
|---|---|---|---|---|---|---|---|
| SCOPE-M0-001 | M0 | P0 | Accepted | Establish scope document | None | Scope and frozen boundaries documented | No denylist changes |
| SCOPE-M0-002 | M0 | P0 | Accepted | Establish denylist and allowlist | SCOPE-M0-001 | Forbidden path seed exists and guard can fail on violations | No battle or match core |
| SCOPE-M0-003 | M0 | P0 | Accepted | Current source baseline assessment | None | Current source of truth, front flow, content pipeline, testing strategy, profile, loadout, loading, and front scene controllers read | Read only |
| SCOPE-M0-004 | M0 | P1 | Accepted | CI or script freeze check | SCOPE-M0-002 | Guard script checks diff or explicit path list | No denylist changes |
| TASK-M1-001 | M1 | P0 | Ready | Define wallet data model | M0 | `wallet_balances` and `wallet_ledger_entries` contract ready | Account Service only |
| TASK-M1-002 | M1 | P0 | Ready | Define purchase order model | M0 | `purchase_orders` and idempotency contract ready | Account Service only |
| TASK-M1-003 | M1 | P0 | Ready | Extend owned asset model | M0 | quantity, expire_at, source_ref_id, revision contract ready | Account Service only |
| TASK-M1-004 | M1 | P0 | Ready | Define shop API | M0 | shop catalog and purchase API contract ready | No Game Service queue |
| TASK-M1-005 | M1 | P0 | Ready | Define inventory API | M0 | inventory response contract ready | Account Service only |
| TASK-M1-006 | M1 | P0 | Ready | Define economy CSV | M0 | currencies, tabs, goods, offers source contract ready | No gameplay content truth changes |
| TASK-M1-007 | M1 | P0 | Ready | Define UI asset catalog | M0 | initial `ui_asset_catalog` contract ready | No hardcoded UI resource paths in presentation scripts |
| TASK-M1-008 | M1 | P0 | Ready | Define UI asset naming spec | M0 | login, lobby, room, shop, inventory, loading, HUD asset IDs named | UI resource only |
| TASK-M2-001 | M2 | P0 | Accepted | Add Account Service migration | M1 | migration creates wallet, ledger, orders, grants, and profile/asset extensions | Account Service migrations only |
| TASK-M2-002 | M2 | P0 | Accepted | Implement WalletRepository | TASK-M2-001 | query, credit, debit, revision, ledger primitives support | Account Service only |
| TASK-M2-003 | M2 | P0 | Accepted | Implement InventoryRepository | TASK-M2-001 | query, grant, duplicate handling, ownership validation primitives | Account Service only |
| TASK-M2-004 | M2 | P0 | Accepted | Implement ShopCatalogProvider | M1 | revisioned catalog returns currencies, tabs, goods, offers | No hardcoded client offers |
| TASK-M2-005 | M2 | P0 | Accepted | Implement PurchaseService | TASK-M2-002, TASK-M2-003, TASK-M2-004 | idempotent transaction covers validation, debit, ledger, grant, order result | No client-side authority |
| TASK-M2-006 | M2 | P0 | Accepted | Implement WalletService | TASK-M2-002 | `GET /api/v1/wallet/me` returns WalletState | Account Service only |
| TASK-M2-007 | M2 | P0 | Accepted | Implement InventoryService | TASK-M2-003 | `GET /api/v1/inventory/me` returns InventoryState | Account Service only |
| TASK-M2-008 | M2 | P1 | Accepted | Extend Profile loadout validation | TASK-M2-003 | avatar/title optional fields and ownership validation | No room or battle semantics |
| TASK-M2-009 | M2 | P0 | Accepted | Add HTTP handlers | TASK-M2-005, TASK-M2-006, TASK-M2-007 | wallet, inventory, catalog, purchase routes registered | Account Service only |
| TASK-M3-001 | M3 | P0 | Accepted | Client WalletState, Gateway, UseCase | M2 API | wallet state can fetch and cache revision | No local debit |
| TASK-M3-002 | M3 | P0 | Accepted | Client InventoryState, Gateway, UseCase | M2 API | inventory state can fetch and cache revision | No local grant |
| TASK-M3-003 | M3 | P0 | Accepted | Client ShopCatalogState, Gateway, UseCase | M2 API | shop catalog loads by revision | No hardcoded offer or price |
| TASK-M3-004 | M3 | P0 | Accepted | Client PurchaseResultState | TASK-M3-003 | purchase result and error map handled | idempotency key required |
| TASK-M4-001 | M4 | P0 | Accepted | UiAssetDef and catalog | M1 | generated or runtime catalog exists | Resource IDs only |
| TASK-M4-002 | M4 | P0 | Accepted | UiAssetResolver | TASK-M4-001 | O(1) resolve by asset_id with placeholder or strict failure | No runtime directory scan |
| TASK-M4-005 | M4 | P0 | Accepted | UI missing resource contract test | TASK-M4-002 | catalog contract validates enabled asset IDs | Formal fail on missing |
| TASK-M5-002 | M5 | P0 | Accepted | LoginScreen formalization | M4 | login background, panel, inputs, and buttons bind UI asset IDs | No auth rewrite |
| TASK-M5-003 | M5 | P0 | Accepted | LobbyScreen formalization | M3, M4 | player card, wallet, shop entry, inventory entry | No match changes |
| TASK-M5-004 | M5 | P0 | Accepted | ShopScreen formalization | M3, M4 | goods and prices from catalog, purchase refreshes wallet and inventory | No local purchase |
| TASK-M5-005 | M5 | P0 | Accepted | InventoryScreen formalization | M3, M4 | equip goes through server patch loadout | Server validates |
| TASK-M5-006 | M5 | P0 | Accepted | RoomScreen formalization | M3, M4 | loadout preview consumes profile and existing room snapshot | No Room FSM changes |
| TASK-M5-008 | M5 | P1 | Accepted | Battle HUD resource-only formalization | M4 | HUD visual roles are bound to UI asset IDs | No battle core changes |
| TASK-M6-001 | M6 | P0 | Accepted | AsyncLoadingTask model | M1 | task status, progress, weight, error are testable | No fake progress |
| TASK-M6-006 | M6 | P0 | Accepted | Loading progress aggregator | TASK-M6-001 | weighted progress is correct and stable | No battle entry semantic change |
| TASK-M7-006 | M7 | P0 | Accepted | Forbidden path check | All | denylist diff passes or has approved exception | Blocks on violation |

## Current Execution

- Active task: None.
- Next task: completion review or user-directed polish.
