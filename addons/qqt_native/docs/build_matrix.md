# qqt_native Build Matrix

Current validated support is intentionally narrow:

- Platform: `windows`
- Arch: `x86_64`
- Targets: `template_debug`, `template_release`
- Editor loading: `windows.editor.x86_64` reuses the `template_debug` DLL

Runtime policy:

- Native kernels are the default authoritative path in local runtime.
- `NativeFeatureFlags.require_native_kernels` defaults to `true`; if a required kernel is missing, mainline battle code reports an error instead of silently falling back to GDScript.
- GDScript fallback code remains only as an explicit parity/test path when native flags are disabled by tests.

Generated artifacts:

- `addons/qqt_native/bin/` is intentionally ignored by git.
- `tools/native/build_native.ps1` and `tools/native/build_native.sh` rebuild the extension from source.
- If the matching `godot-cpp` static library is absent, the build script builds it first.
- `tools/run-services.ps1` and `scripts/run-battle-ds-local.ps1` call the native build before launching Godot-driven runtime.
- `deploy/docker/build_phase24_dev.ps1` prepares local generated inputs before Docker Compose build.

Current non-goals in this repo state:

- `linux` artifacts are not shipped
- `macos` artifacts are not shipped
- non-`x86_64` artifacts are not shipped

Why the scope is restricted:

- The repo's `SConstruct` and build scripts are validated against the Windows MSVC toolchain used by local development and CI-like native suite runs.
- Docker service images currently build Go services. They do not provide a validated Linux Godot runtime plus Linux `qqt_native` artifact.

Before enabling another platform, all of the following must be added together:

1. Matching `godot-cpp` static libraries for that platform/arch/target.
2. Platform-specific compiler and linker wiring in `addons/qqt_native/SConstruct`.
3. Correct output artifact naming that matches `qqt_native.gdextension`.
4. A platform-specific verification path that actually builds and loads the extension.
