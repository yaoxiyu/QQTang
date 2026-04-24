# Phase32 Native Frame Sync Refactor

Phase32 refactors battle frame sync by adding an authority batch boundary before runtime ingestion, then exposing the same deterministic planning path through native shadow and execute modes.

## Files

- `phase32_source_audit.md`: source facts and current sync debt.
- `phase32_system_design.md`: target architecture and native module boundaries.
- `phase32_implementation_plan.md`: atomic implementation cards.
- `phase32_acceptance.md`: acceptance gates and rollback policy.

## Scope

Delivered:

1. GDScript authority batch coalescing boundary.
2. Native authority batch coalescer shadow parity.
3. Native authority batch coalescer execute mode after parity.
4. Native input buffer shadow.
5. Native snapshot diff and rollback planner shadow.
6. Native battle message codec shadow.
7. Performance, soak, and fault-profile coverage.

Execute modes:

- Authority batch coalescer is enabled in native execute mode.
- Input buffer, snapshot diff, rollback planner, and battle message codec are enabled in native execute mode with shadow checks still available.
