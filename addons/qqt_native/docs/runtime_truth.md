# qqt_native Runtime Truth

## Mainline Policy

- Phase30 native kernels are now the default battle runtime path.
- `NativeFeatureFlags.require_native_kernels` defaults to `true`.
- If checksum, snapshot ring, movement, or explosion native kernels are requested but unavailable, the mainline code reports an error instead of silently using the legacy path.
- Legacy GDScript implementations remain only behind explicit test flags for parity and regression tests.

## How To Prove Native Is Active

1. Start through `tools/run-services.ps1` or `scripts/run-battle-ds-local.ps1`.
2. Confirm `addons/qqt_native/bin/qqt_native.windows.template_debug.x86_64.dll` was rebuilt.
3. Run `tools/native/check_native_runtime.ps1`; it builds the extension and checks `ClassDB`, kernel version, required flags, and native availability.
4. Run `tests/scripts/run_native_suite.ps1`; it builds the extension and verifies unit, integration, and performance native paths.

## Clean Workspace Rebuild

Ignored/generated artifacts may be deleted:

- `addons/qqt_native/bin/`
- `addons/qqt_native/third_party/godot-cpp/bin/`
- `addons/qqt_native/third_party/godot-cpp/gen/`
- `build/generated/room_manifest/`
- `tests/reports/`
- `logs/`

Local scripts regenerate the required pieces:

- `tools/native/build_native.ps1` rebuilds `godot-cpp` static libraries when missing, then `qqt_native`.
- `tools/run-services.ps1` builds native and regenerates the room manifest before launching services.
- `scripts/run-battle-ds-local.ps1` builds native before launching the dedicated server scene.
- `deploy/docker/build_phase24_dev.ps1` builds native and regenerates the room manifest before `docker compose build`.

## Docker Limitation

The current Docker service images build Go services. They do not yet provide a validated Linux Godot runtime plus Linux `qqt_native` GDExtension artifact. Docker Compose can build account/game/ds-manager/room service images after generated inputs are prepared, but Linux dedicated-server native execution requires a future Linux build matrix entry.
