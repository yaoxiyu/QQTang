# Current Source Of Truth (Index)

Scope: current repository implementation after Phase26 control-plane closure and legacy/compat removal.
Positioning: this file is index and governance only. Domain truth is in split architecture docs.

## 1. Global Rules
1. Authority layering:
global governance in this file, domain semantics in `docs/architecture/*.md`.
2. Conflict resolution:
prefer narrower and code-nearer domain doc. If still conflicting, repository code and committed contract tests win.
3. Archive policy:
`docs/archive/*` is historical evidence, not current implementation truth.
4. No monolith rollback:
do not re-merge domain semantics into this index.

## 2. Architecture Index
- Runtime topology: [`docs/architecture/runtime_topology.md`](./architecture/runtime_topology.md)
- Front flow: [`docs/architecture/front_flow.md`](./architecture/front_flow.md)
- Network control plane: [`docs/architecture/network_control_plane.md`](./architecture/network_control_plane.md)
- Room protocol: [`docs/architecture/room_protocol.md`](./architecture/room_protocol.md)
- Room manifest: [`docs/architecture/room_manifest.md`](./architecture/room_manifest.md)
- Content pipeline: [`docs/architecture/content_pipeline.md`](./architecture/content_pipeline.md)
- Testing strategy: [`docs/architecture/testing_strategy.md`](./architecture/testing_strategy.md)
- Room service runtime contract: [`docs/platform_room/room_service_runtime_contract.md`](./platform_room/room_service_runtime_contract.md)
- Architecture debt register: [`docs/architecture_debt_register.md`](./architecture_debt_register.md)

## 3. Boundary Of Documentation Authority
1. `docs/current_source_of_truth.md`:
index, governance rules, and doc ownership boundaries only.
2. `docs/architecture/*.md` and `docs/platform_room/*.md`:
formal domain semantics and constraints for implementation alignment.
3. `docs/archive/*.md`:
phase records and historical decisions only.

## 4. Maintenance Requirements
1. Any runtime or protocol change must update matched domain docs in the same change set.
2. New architecture domains must be added to `docs/architecture/` first, then indexed here.
3. Every normative statement must map to concrete code paths and committed tests.
