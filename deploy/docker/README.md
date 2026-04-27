# Docker Deployment Scope

The Docker Compose files validate Go service image readiness for:

- `account_service`
- `room_service`
- `game_service`
- `ds_manager_service`

They do not validate Linux Godot dedicated-server native runtime readiness by themselves.

Before claiming Linux Godot DS native runtime readiness, a Linux host or CI runner must pass:

```bash
GODOT_BIN=/path/to/godot ./tools/native/check_native_runtime_linux.sh
```

That command must build both Linux artifacts and load the debug artifact:

- `addons/qqt_native/bin/qqt_native.linux.template_debug.x86_64.so`
- `addons/qqt_native/bin/qqt_native.linux.template_release.x86_64.so`

Until that check has passed, Docker/k8s deployment status may only claim Go service readiness, not production readiness for Godot DS with `qqt_native`.
