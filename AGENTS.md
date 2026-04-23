# QQTang Repo Rules

## Mandatory GDScript Preflight

- Before running any GDScript-based pipeline, contract test, integration test, or ad-hoc Godot script, run a GDScript syntax preflight first.
- If the syntax preflight reports any parse/load error, stop immediately. Do not continue to pipeline execution or GDScript tests until the syntax errors are fixed.
- Treat this as a hard gate, not a best-effort check.

## Required Commands

- Syntax preflight:
  - `powershell -ExecutionPolicy Bypass -File tests/scripts/check_gdscript_syntax.ps1`
- Content pipeline:
  - `powershell -ExecutionPolicy Bypass -File scripts/content/run_content_pipeline.ps1`
- Content validation:
  - `powershell -ExecutionPolicy Bypass -File scripts/content/validate_content_pipeline.ps1`

## Execution Order

1. Run GDScript syntax preflight.
2. Only if syntax preflight passes, run the requested Godot pipeline or test command.
3. If a command fails, report whether the failure is syntax, content data, runtime script, or environment related.
