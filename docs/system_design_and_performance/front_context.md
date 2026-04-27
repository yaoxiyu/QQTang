# Front Context

## Current State

The project has moved from demo architecture toward formal engineering architecture:

- Godot 4.6 is the client and partial DS runtime environment.
- Formal front flow is under `app/flow/` and `app/front/`.
- Room, Lobby, Auth, Profile, Matchmaking, and Settlement already have first-pass use case / gateway / state separation.
- Room Service is Go-based and consumes the generated Room Manifest as the cross-language legality snapshot.
- Content data flows from `content_source/csv/` through `tools/content_pipeline/` into `content/*/data`, runtime catalogs, and `build/generated/room_manifest/room_manifest.json`.
- Native kernels were introduced for checksum, snapshot ring, movement, and explosion.
- `NativeFeatureFlags.require_native_kernels` defaults to true, so native kernels are now the default local battle runtime path.
- Current native build validation is Windows x86_64 only; Linux Godot runtime plus Linux `qqt_native` artifact is not closed.

## Optimization Pressure

- `app/front/room/room_use_case.gd`, `app/front/lobby/lobby_use_case.gd`, and `app/front/room/room_view_model_builder.gd` are still large enough to become new gravity centers.
- Some runtime catalogs still scan `.tres` directories and load resources at startup.
- The native packed codec still crosses Variant/Dictionary/Array boundaries.
- The native snapshot ring copies `PackedByteArray` values without exposing enough metrics.
- Docker currently proves Go service image readiness, not Linux Godot DS native runtime readiness.

## Boundary

This is a hardening scope:

- Split the first batch of Room/Lobby front logic behind stable facades.
- Add generated catalog index support while keeping scan fallback.
- Document and scaffold the packed battle runtime schema.
- Add native snapshot ring metrics and size limits.
- Add logging and duplicate hot-path guardrails.
- Add Linux native build matrix scripts and documentation without overstating readiness.
