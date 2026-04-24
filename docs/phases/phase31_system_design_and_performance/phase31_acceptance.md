# Phase31 Acceptance

## Required Files

- `docs/phases/phase31_system_design_and_performance/README.md`
- `docs/phases/phase31_system_design_and_performance/phase31_front_context.md`
- `docs/phases/phase31_system_design_and_performance/phase31_system_design.md`
- `docs/phases/phase31_system_design_and_performance/phase31_implementation_plan.md`
- `docs/phases/phase31_system_design_and_performance/phase31_acceptance.md`
- `addons/qqt_native/docs/battle_packed_runtime_schema.md`

## Front Split

Required first-batch files:

- `app/front/room/commands/room_enter_command.gd`
- `app/front/room/commands/room_queue_command.gd`
- `app/front/room/commands/room_battle_entry_command.gd`
- `app/front/room/projection/room_snapshot_projector.gd`
- `app/front/room/projection/room_capability_projector.gd`
- `app/front/room/projection/room_member_projector.gd`
- `app/front/room/recovery/room_reconnect_flow.gd`
- `app/front/room/recovery/room_resume_flow.gd`
- `app/front/room/errors/room_error_mapper.gd`
- `app/front/common/view_revision_guard.gd`

`RoomUseCase` external methods must keep their signatures.

## Generated Catalog Index

The content pipeline must generate:

- `build/generated/content_catalog/characters_catalog_index.json`
- `build/generated/content_catalog/bubbles_catalog_index.json`
- `build/generated/content_catalog/maps_catalog_index.json`
- `build/generated/content_catalog/modes_catalog_index.json`
- `build/generated/content_catalog/rulesets_catalog_index.json`
- `build/generated/content_catalog/match_formats_catalog_index.json`
- `build/generated/content_catalog/content_catalog_summary.json`

Character and Bubble catalogs must prefer generated index and keep scan fallback.

## Packed Runtime Schema

Schema docs and adapter tests must cover:

- `SCHEMA_VERSION = 1`
- header stride
- player stride
- bubble stride
- item stride
- grid stride
- cell, subcell, tick, and hash units
- reserved-field compatibility
- Dictionary codec migration policy

## Native Snapshot Ring

Metrics must expose capacity, max snapshot bytes, put/get/hit/miss counts, overwrite count, rejected-too-large count, and total bytes written.

## Validation Commands

Before any GDScript-based pipeline or test:

```powershell
powershell -ExecutionPolicy Bypass -File tests/scripts/check_gdscript_syntax.ps1
```

Then run targeted commands as needed:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/content/run_content_pipeline.ps1
powershell -ExecutionPolicy Bypass -File scripts/content/validate_content_pipeline.ps1
powershell -ExecutionPolicy Bypass -File tools/native/check_native_runtime.ps1
powershell -ExecutionPolicy Bypass -File tests/scripts/run_native_suite.ps1
```

Linux native validation requires a Linux host or CI:

```bash
GODOT_BIN=/path/to/godot ./tools/native/check_native_runtime_linux.sh
```
