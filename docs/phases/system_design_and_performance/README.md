# Current System Design And Performance

Current is a system design and performance-hardening phase after the Current native kernel rollout.

This phase does not add gameplay, redesign UI, rewrite DS lifecycle, or remove the GDScript simulation fallback. It keeps the current main flow and hardens the runtime boundaries that already exist.

## Current Truth

- Current does not change the main business flow and does not add new gameplay.
- Front Room/Lobby continues to use `app/front/*`, but `RoomUseCase` and `LobbyUseCase` must not keep absorbing all business details.
- Runtime Catalog should prefer `build/generated/content_catalog/*_catalog_index.json`; directory scanning is only an editor/dev fallback.
- Battle native kernels remain the default authoritative runtime path.
- The battle packed runtime schema is the formal wire contract between GDScript and native kernels.
- Linux `qqt_native` artifacts must be built and runtime-checked before claiming Godot DS Linux native runtime readiness.

## Documents

- `front_context.md`: current project context and observed pressure points.
- `system_design.md`: design decisions and target boundaries.
- `implementation_plan.md`: ordered atomic implementation steps.
- `acceptance.md`: acceptance criteria and validation commands.

