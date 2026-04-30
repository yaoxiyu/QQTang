from __future__ import annotations

import json
from pathlib import Path

from .asset_validation_result import PipelineResult


def write_reports(project_root: Path, results: list[PipelineResult]) -> None:
    latest_dir = project_root / "tests" / "reports" / "latest"
    latest_dir.mkdir(parents=True, exist_ok=True)
    payload = {
        "phase": "Phase38",
        "status": "pass" if all(result.ok for result in results) else "fail",
        "package_count": len(results),
        "packages": [result.to_dict() for result in results],
    }
    json_path = latest_dir / "phase38_asset_pipeline_latest.json"
    md_path = latest_dir / "phase38_asset_pipeline_latest.md"
    txt_path = latest_dir / "phase38_asset_pipeline_latest.txt"
    json_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    lines = ["# Phase38 Asset Pipeline Latest", "", f"status: {payload['status']}", ""]
    for result in results:
        lines.append(f"- {result.asset_type}/{result.asset_key}: {'pass' if result.ok else 'fail'}")
    md_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    txt_path.write_text(f"status={payload['status']}\npackage_count={len(results)}\n", encoding="utf-8")
