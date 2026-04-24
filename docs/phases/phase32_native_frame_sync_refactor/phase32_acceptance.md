# Phase32 Acceptance

Minimum acceptance:

1. Client poll batches are coalesced before authority runtime ingestion.
2. One rendered client frame triggers at most one rollback or full resync.
3. Stale authority snapshots are dropped at the batch boundary.
4. Intermediate snapshot events are preserved by tick and consumed in order.
5. `MATCH_FINISHED` is not dropped and is applied after coalesced authority state.
6. Native coalescer shadow parity is covered before execute mode is enabled.
7. Native input buffer execute mode drops stale-seq and too-late input with metrics.
8. Native snapshot diff and rollback planner execute mode preserves rollback/resync/noop decisions.
9. Native battle message codec execute mode emits native binary payloads while JSON decode remains compatible.

Required commands:

```powershell
powershell -ExecutionPolicy Bypass -File tests/scripts/check_gdscript_syntax.ps1
powershell -ExecutionPolicy Bypass -File tools/native/build_native.ps1
powershell -ExecutionPolicy Bypass -File tools/native/check_native_runtime.ps1
powershell -ExecutionPolicy Bypass -File tests/scripts/run_native_suite.ps1
powershell -ExecutionPolicy Bypass -File tests/scripts/run_network_suite.ps1
```

Rollback switches:

```gdscript
enable_native_authority_batch_coalescer_execute = false
enable_native_authority_batch_coalescer_shadow = false
enable_native_input_buffer_execute = false
enable_native_snapshot_diff_execute = false
enable_native_rollback_planner_execute = false
enable_native_battle_message_codec_execute = false
```

Current Phase32 defaults:

```gdscript
enable_native_authority_batch_coalescer_execute = true
enable_native_authority_batch_coalescer_shadow = true
enable_native_input_buffer_execute = true
enable_native_snapshot_diff_execute = true
enable_native_rollback_planner_execute = true
enable_native_battle_message_codec_execute = true
```
