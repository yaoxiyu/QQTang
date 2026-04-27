# Implementation Plan

## Order

1. Write docs and truth update.
2. Add first-batch Room UseCase command/projection/recovery/error split.
3. Add Generated Catalog Index loader, contract helper, and generator.
4. Make Character and Bubble catalogs prefer generated index with scan fallback.
5. Add Battle Packed Runtime Schema docs and adapter scaffolding.
6. Add Native Snapshot Ring metrics and size limits.
7. Add logging and duplicate hot-path helpers.
8. Add Linux native build matrix scripts, `.gdextension` mappings, and docs.
9. Run GDScript syntax preflight before every GDScript pipeline/test command, then run targeted validation.

## Guardrails

- Do not rewrite `RoomUseCase` wholesale.
- Do not delete GDScript fallback paths.
- Do not modify `.tscn` scene structure or complex `.tres` resources by hand.
- Do not make generated catalog index the only runtime path.
- Do not change Room Manifest semantic field names without updating Go Room Service and tests.
- Do not treat Linux script existence as Linux native runtime verification.
- Do not stringify full room/battle snapshots in tick hot paths.
- Do not deep-duplicate large payloads only for logging.

## Rollback Strategy

- Front split failure: remove only the facade delegation from `RoomUseCase`; keep new isolated classes and tests.
- Catalog failure: disable generated-index priority and keep fallback scanning.
- Native C++ failure: revert Snapshot Ring C++ metrics changes while keeping schema docs and GDScript adapter.
- Linux build failure: keep scripts and docs, but mark the matrix entry as unverified.
