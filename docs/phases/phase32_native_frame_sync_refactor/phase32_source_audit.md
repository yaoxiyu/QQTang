# Phase32 Source Audit

Source date: 2026-04-24.

Current battle sync is GDScript orchestration with selected GDExtension kernels. Native code already covers checksum, snapshot ring, packed snapshot payload codec, movement, and explosion. The frame-sync control plane still lives in GDScript.

Primary debt:

- `DEBT-010 battle authority batch consumption not coalesced`.
- Client transport poll can deliver several authority snapshots in one batch.
- `RuntimeMessageRouter` dispatches each message immediately.
- Each `CHECKPOINT` or `AUTHORITATIVE_SNAPSHOT` can trigger rollback.

Related semantic risk:

- `STATE_SUMMARY` must not patch historical `snapshot_buffer` rollback evidence.
- Summary is a current-world sideband recovery mechanism, not checkpoint truth.

Native extraction order:

1. Authority batch coalescer.
2. Input buffer.
3. Snapshot diff.
4. Rollback planner.
5. Battle message codec.

Do not move high-level `ClientRuntime`, `AuthorityRuntime`, or `RuntimeMessageRouter` into C++ while their semantics remain Dictionary-heavy.
