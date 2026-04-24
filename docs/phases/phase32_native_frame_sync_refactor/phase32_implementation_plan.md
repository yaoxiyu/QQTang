# Phase32 Implementation Plan

Execution order:

```text
P32-00 docs and debt register sync
P32-01 GDScript authority batch boundary
P32-02 Native authority batch coalescer shadow
P32-03 Native authority batch coalescer execute
P32-04 Native input buffer shadow
P32-05 Native snapshot diff and rollback planner shadow
P32-06 Native battle message codec shadow
P32-07 performance, soak, fault injection
P32-08 closeout and defaults
```

Hard gates:

1. Run GDScript syntax preflight before GDScript tests or pipelines.
2. Every native module ships shadow before execute.
3. Do not delete GDScript fallback paths.
4. Do not edit `.tscn`, `.tres`, `.res`, `.uid`, or `project.godot` for this phase.
5. New native classes must be registered, built, runtime checked, and tested.

Minimum deliverable is P32-00 through P32-03.

Execution status:

```text
P32-00 done
P32-01 done
P32-02 done
P32-03 done
P32-04 done, execute enabled
P32-05 done, execute enabled
P32-06 done, execute enabled
P32-07 done
P32-08 done
```
