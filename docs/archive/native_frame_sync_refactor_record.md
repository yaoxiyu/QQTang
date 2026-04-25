# Native Frame Sync Refactor Record

> Historical execution record. Current battle sync truth lives in `docs/architecture/battle_sync.md`.

## Source Audit

Initial state:

- battle sync used GDScript orchestration with selected GDExtension kernels;
- native already covered checksum, snapshot ring, packed snapshot payload codec, movement, and explosion;
- authority message consumption was not coalesced before runtime ingestion;
- input buffering, snapshot diff, rollback planning, and project message codec were still GDScript-heavy.

Primary risk:

- one transport poll could deliver several authority snapshots;
- each `CHECKPOINT` / `AUTHORITATIVE_SNAPSHOT` could trigger rollback independently;
- this created CPU spikes and correction churn after network stalls.

Extraction order:

1. Authority batch coalescer.
2. Input buffer and late input policy.
3. Snapshot diff.
4. Rollback planner.
5. Battle message codec.

## Implementation Record

Delivered:

- client authority batch boundary before runtime ingestion;
- native authority batch coalescer;
- native input buffer bridge used by `InputBuffer` and `AuthorityRuntime`;
- native snapshot diff;
- native rollback planner;
- native battle message codec;
- native-only runtime bridge cleanup after parity work;
- old shadow, execute, and GDScript fallback paths removed from the sync bridge layer;
- old shadow/parity tests and orphan `.uid` files removed.

Current non-goals:

- high-level runtime routing stays in GDScript;
- rollback replay loop stays in GDScript;
- scene, lifecycle, and presentation handoff stay in GDScript;
- movement and explosion still have coarse enable flags and should be treated as a remaining cleanup risk.

## Acceptance

Current expected behavior:

- authority messages are coalesced before `ClientRuntime.ingest_authority_batch()`;
- one rendered client frame triggers at most one rollback or full resync;
- stale authority snapshots are dropped at the batch boundary;
- intermediate authority events are preserved by tick;
- `MATCH_FINISHED` is applied after coalesced authority state;
- input buffer accepts future input, retargets late input, and drops stale or too-late input in native;
- snapshot diff and rollback planner decisions come from native;
- byte transport payloads use native codec envelopes;
- malformed native payloads fail safe.

Validation at cleanup:

```text
GDScript syntax preflight: PASS, checked=749
native_chain_cleanup: PASS, total=11
```
