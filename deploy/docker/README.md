# Docker Deployment Scope

## Service startup

Use the repository-level service entrypoint:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\run-services.ps1 -Profile dev
```

That entrypoint owns DB startup, DB migration, native debug build, GDScript syntax preflight, room manifest generation, and Docker Compose service startup.

`run-services.ps1` uses input-file fingerprints to skip unchanged build targets. Use `-ForceBuild` when a full rebuild is required:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\run-services.ps1 -Profile dev -ForceBuild
```

## Retained deployment scripts

- `tools/run-services.ps1`: canonical Docker service startup entrypoint.
- `tools/db-up.ps1`: starts profile-scoped Postgres containers.
- `tools/db-migrate.ps1`: creates missing DBs and applies idempotent SQL migrations.
- `scripts/docker/export_battle_ds_linux.ps1`: exports the Linux Battle DS Godot binary and pack.
- `scripts/docker/build_battle_ds_image.sh`: builds the `qqtang/battle-ds:dev` runtime image from exported Battle DS artifacts.
- `tools/native/build_native_linux_docker.ps1`: builds Linux native extension artifacts in the pinned Linux build container.
- `tools/native/check_native_runtime_linux.sh`: validates Linux Godot native runtime readiness.

Removed deployment-era compatibility scripts:

- `tools/run_dev_services.ps1`
- `tools/migrate.ps1`
- `deploy/docker/build_services_dev.ps1`
- `scripts/run-room-service.ps1`
- `network/scripts/run-room-service.ps1`

The service Docker Compose files validate Go service image readiness for:

- `account_service`
- `room_service`
- `game_service`
- `ds_manager_service`

They do not start Postgres. Local DB containers remain managed by `tools/db-up.ps1`.

They do not validate Linux Godot dedicated-server native runtime readiness by themselves.

Before claiming Linux Godot DS native runtime readiness, a Linux host or CI runner must pass:

```bash
GODOT_BIN=external/godot_binary/Godot_console.exe ./tools/native/check_native_runtime_linux.sh
```

That command must build both Linux artifacts and sync the DS packaging inputs under `external/qqt_native/bin/`:

- `external/qqt_native/bin/qqt_native.linux.template_debug.x86_64.so`
- `external/qqt_native/bin/qqt_native.linux.template_release.x86_64.so`

Godot still loads the native extension from `addons/qqt_native/bin/` at runtime, so the Linux runtime check also keeps a local loader copy there.

Until that check has passed, Docker/k8s deployment status may only claim Go service readiness, not production readiness for Godot DS with `qqt_native`.
