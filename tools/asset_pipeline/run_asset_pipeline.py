from __future__ import annotations

import argparse
import sys
from pathlib import Path

if __package__ is None or __package__ == "":
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from tools.asset_pipeline.core.asset_manifest import validate_manifest_shape, validate_write_rights
from tools.asset_pipeline.core.asset_package import AssetPackage
from tools.asset_pipeline.core.asset_spec_registry import get_spec
from tools.asset_pipeline.core.asset_validation_result import PipelineResult, StageResult
from tools.asset_pipeline.core.csv_patch_writer import CsvPatchWriter
from tools.asset_pipeline.core.plugin_registry import discover_plugins
from tools.asset_pipeline.core.report_writer import write_reports


def _package_roots(project_root: Path, asset_type: str | None, asset_key: str | None, all_packages: bool) -> list[Path]:
    intake_root = project_root / "content_source" / "asset_intake"
    if all_packages:
        roots: list[Path] = []
        if not intake_root.exists():
            return roots
        for manifest in intake_root.glob("*/*/manifest.json"):
            roots.append(manifest.parent)
        return sorted(roots)
    if not asset_type or not asset_key:
        raise ValueError("AssetType and AssetKey are required unless -All is used")
    return [intake_root / asset_type / asset_key]


def _run_package(project_root: Path, package_root: Path, write_csv: bool, generate_variants: bool) -> PipelineResult:
    parse_stage = StageResult(stage="parse_manifest")
    try:
        package = AssetPackage.from_root(package_root)
    except Exception as exc:
        parse_stage.fail(str(exc))
        result = PipelineResult(str(package_root), "", "", "", [parse_stage])
        return result

    result = PipelineResult(
        package_path=str(package.root.relative_to(project_root) if package.root.is_relative_to(project_root) else package.root),
        asset_type=package.manifest.asset_type,
        asset_key=package.manifest.asset_key,
        spec_id=package.manifest.spec_id,
        stages=[parse_stage],
        rights_status=package.manifest.review_status,
    )

    shape_stage = StageResult(stage="validate_schema")
    for error in validate_manifest_shape(package.manifest):
        shape_stage.fail(error)
    result.stages.append(shape_stage)
    if shape_stage.status == "fail":
        return result

    try:
        spec = get_spec(package.manifest.spec_id)
    except KeyError as exc:
        spec_stage = StageResult(stage="resolve_spec")
        spec_stage.fail(str(exc))
        result.stages.append(spec_stage)
        return result
    spec_stage = StageResult(stage="resolve_spec")
    if spec.asset_type != package.manifest.asset_type:
        spec_stage.fail(f"spec {spec.spec_id} expects asset_type {spec.asset_type}, got {package.manifest.asset_type}")
    result.stages.append(spec_stage)
    if spec_stage.status == "fail":
        return result

    plugins = discover_plugins(Path(__file__).resolve().parent / "plugins")
    plugin = plugins.get(package.manifest.asset_type)
    plugin_stage = StageResult(stage="resolve_plugin")
    if plugin is None:
        plugin_stage.fail(f"missing asset plugin for type: {package.manifest.asset_type}")
        result.stages.append(plugin_stage)
        return result
    result.stages.append(plugin_stage)

    preflight = plugin.preflight(package, spec, project_root)
    result.stages.append(preflight)
    if preflight.status == "fail":
        return result

    result.stages.append(plugin.normalize(package, spec, project_root))
    if generate_variants:
        result.stages.append(plugin.generate_variants(package, spec, project_root))

    rights_stage = StageResult(stage="rights_gate")
    if write_csv:
        for error in validate_write_rights(package.manifest):
            rights_stage.fail(error)
    result.stages.append(rights_stage)
    if rights_stage.status == "fail":
        return result

    patch_stage = StageResult(stage="build_csv_patch")
    plans = plugin.build_csv_patch(package, spec, project_root)
    writer = CsvPatchWriter(project_root)
    for plan in plans:
        summary = writer.apply(plan, write=write_csv)
        result.csv_patch_summary.append(summary)
        patch_stage.outputs.append(plan.path)
    result.stages.append(patch_stage)

    report_stage = StageResult(stage="write_report")
    result.stages.append(report_stage)
    write_reports(project_root, [result])
    return result


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Run Phase38 asset pipeline.")
    parser.add_argument("--project-root", default=str(Path(__file__).resolve().parents[2]))
    parser.add_argument("--asset-type", default="")
    parser.add_argument("--asset-key", default="")
    parser.add_argument("--all", action="store_true")
    parser.add_argument("--write-csv", action="store_true")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--generate-variants", action="store_true")
    args = parser.parse_args(argv)

    project_root = Path(args.project_root).resolve()
    try:
        roots = _package_roots(project_root, args.asset_type or None, args.asset_key or None, args.all)
        results = [_run_package(project_root, root, write_csv=args.write_csv and not args.dry_run, generate_variants=args.generate_variants) for root in roots]
        if not results:
            write_reports(project_root, [])
            print("[asset_pipeline] no asset packages found")
            return 0
        write_reports(project_root, results)
        for result in results:
            print(f"[asset_pipeline] {result.asset_type}/{result.asset_key}: {'PASS' if result.ok else 'FAIL'}")
        return 0 if all(result.ok for result in results) else 1
    except Exception as exc:
        print(f"[asset_pipeline] failed: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
