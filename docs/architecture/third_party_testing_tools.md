# Third Party Testing Tools

## Scope

This project uses `addons/gut/` as third party testing infrastructure.

## Source Ownership

- `addons/gut/` is third party code.
- Do not modify GUT source files for project behavior changes.

## Adaptation Rules

- Compatibility adjustments must be implemented in project-owned layers:
  - `tests/gut/base/*`
  - `tests/scripts/run_gut_suite.ps1`
- Keep business tests dependent on project test base classes instead of direct third party internals.
