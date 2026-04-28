# Current Manual Acceptance

This file tracks the remaining checks that require running real battle flows outside the unit/contract suites.

## Required Manual Checks

1. 2P normal battle steady state:
   - No `QQT_INPUT_BATCH_BUDGET_WARN` after bootstrap/opening.
   - `battle unreliable payload promoted to reliable` count stays 0 after bootstrap/opening.
   - `transport_unreliable_promoted_to_reliable_count` stays 0 for `INPUT_BATCH`, `STATE_SUMMARY`, and `STATE_DELTA`.

2. 4P battle soak:
   - p95 `INPUT_BATCH` payload bytes is below `BattleWireBudgetContract.UNRELIABLE_SOFT_LIMIT_BYTES`.
   - p95 `STATE_SUMMARY` payload bytes is below `BattleWireBudgetContract.UNRELIABLE_SOFT_LIMIT_BYTES`.
   - Any promotion during steady state is a failure signal, not a tolerated path.

3. Normal client and dedicated-server shutdown:
   - No `ObjectDB instances leaked`.
   - No `resources still in use`.
   - No RID leak warnings.
   - No thread destroyed without completion warnings.
   - Forced-stop runs must be classified as `expected_interruption` and kept separate from normal shutdown evidence.

## Automated Checks Already Covering Code Structure

- `tests/scripts/check_gdscript_syntax.ps1`
- `tests/scripts/run_refactor_validation.ps1`
- `tests/scripts/run_cross_service_contract_suite.ps1`
- `tests/unit/network`
- `tests/unit/native`
- `tests/performance/native/native_frame_sync_soak_test.gd`

