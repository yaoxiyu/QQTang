# Room Manifest

## Scope
Define Room legality source of truth and generation pipeline for the service runtime.

## Source And Artifact
- Source data: content pipeline catalog inputs under `content_source/csv/`.
- Generator: `tools/content_pipeline/generators/generate_room_manifest.gd`.
- Pipeline entry: `tools/content_pipeline/content_pipeline_runner.gd`.
- Generated artifact: `build/generated/room_manifest/room_manifest.json`.

## Required Manifest Semantics
- Map legality set.
- Mode and rule binding per map.
- Match format and legal mode set mapping.
- Map enable flags for custom/casual/ranked.
- Team and player count constraints.
- Default assets and legal asset ID sets.
- `match_formats` must come from `content/match_formats/*`, not string parsing heuristics.
- `maps.match_format_ids` must be generated from `content_source/csv/maps/map_match_variants.csv`.
- `required_party_size` and `expected_total_player_count` must come from `MatchFormatDef`.

## Runtime Usage
- Go Room Service loads manifest from `ROOM_MANIFEST_PATH`.
- Selection legality and map-pool resolution use manifest query layer:
  - `services/room_service/internal/manifest/query.go`
- Room Service must not depend on Godot runtime catalog scripts for legality.

## Contracts
- Content contracts:
  - `tests/contracts/content/room_manifest_export_contract_test.gd`
  - `tests/contracts/content/room_manifest_matches_catalog_contract_test.gd`
- Room Service loader contract:
  - `services/room_service/internal/manifest/loader_test.go`
