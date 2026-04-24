# Phase32 System Design

Phase32 keeps Godot lifecycle in GDScript and moves deterministic sync planning into GDExtension modules behind feature flags.

Target poll path:

```text
consume_incoming()
  -> route non-authority messages
  -> coalesce authority messages
  -> ClientRuntime.ingest_authority_batch()
  -> at most one rollback/resync
  -> emit presentation tick once
```

First native class:

```text
QQTNativeAuthorityBatchCoalescer
```

Feature flag policy:

- Shadow before execute.
- GDScript fallback remains available.
- Native execute is not enabled until parity and DEBT-010 acceptance tests pass.

Metrics must expose incoming batch size, raw checkpoint count, dropped stale snapshots, dropped intermediate snapshots, preserved event ticks, and shadow parity status.
