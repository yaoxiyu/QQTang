# System Design

## Design Summary

Do not change the main business flow or rewrite working runtime paths. Harden boundaries, slim hot paths, prefer generated data, and make the native packed schema explicit.

The existing mainline remains:

```text
Godot Front App
  app/flow
  app/front

Content Runtime
  content/*/defs
  content/*/data
  content/*/catalog

Content Pipeline
  content_source/csv
  tools/content_pipeline
  build/generated/room_manifest

Battle Runtime
  gameplay/simulation
  gameplay/native_bridge
  addons/qqt_native

Network / Service
  network/session
  network/runtime/room_client
  services/room_service
```

## Front UseCase Boundary

`RoomUseCase` remains the external facade. Internally, first-batch responsibilities move toward:

- `commands/`: user intent to gateway/runtime calls.
- `projection/`: authoritative snapshot to view model projection.
- `recovery/`: reconnect and resume flow decisions.
- `errors/`: bottom-level error codes to front-facing errors.

The public API must stay stable. The first migration is intentionally small to avoid damaging Room/Lobby flow.

## Generated Catalog Index

Runtime catalogs should prefer generated JSON under:

```text
build/generated/content_catalog/
```

Directory scanning and `.tres` loading stay as editor/dev fallback. The generated index is for Godot runtime resource lookup and startup performance. The Room Manifest remains the cross-language room legality truth for Go services.

## Battle Packed Runtime Schema

Native kernels are already the default path. This scope adds a formal schema so future native work can move from Variant/Dictionary parsing toward packed stride access.

The initial schema uses:

- `header: PackedInt32Array`
- `players: PackedInt32Array`
- `bubbles: PackedInt32Array`
- `items: PackedInt32Array`
- `grid: PackedInt32Array`
- `events: PackedInt32Array`

The old Dictionary codec remains for parity and regression tests.

## Snapshot Ring Governance

This scope adds metrics and limits, not delta snapshots or custom allocators:

- capacity
- max snapshot bytes
- put/get/hit/miss counts
- overwrite count
- rejected-too-large count
- total bytes written

## Logging And Duplicate Governance

High-frequency room/battle snapshot paths should log summaries, not full payloads. Deep copy remains valid at authority boundaries, but logging must not force deep duplication of large snapshots.

## Linux Native Matrix

Linux scripts and `.gdextension` mappings are added as build-matrix entry points. The project must not claim production Linux Godot DS native runtime readiness until a Linux host or CI has built and loaded the artifact successfully.
