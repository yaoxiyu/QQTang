# e2e integration

Executable E2E tests in this directory:
- `battle_entry_invalid_ticket_e2e_test.gd`
- `battle_resume_window_e2e_test.gd`

Cross-service control plane lifecycle is executed via:
- `services/ds_manager_service/internal/httpapi/router_internal_auth_test.go` (`TestInternalBattleLifecycleWithSignedAuth`)
- unified script `tests/scripts/run_cross_service_contract_suite.ps1`
