from __future__ import annotations

import json
from dataclasses import dataclass
from pathlib import Path
from typing import Any


REQUIRED_FIELDS = ("asset_type", "asset_key", "spec_id", "content_ids", "source_files", "rights")
REQUIRED_RIGHTS_FIELDS = ("commercial_use", "review_status")


@dataclass(frozen=True)
class AssetManifest:
    path: Path
    data: dict[str, Any]

    @property
    def asset_type(self) -> str:
        return str(self.data.get("asset_type", ""))

    @property
    def asset_key(self) -> str:
        return str(self.data.get("asset_key", ""))

    @property
    def spec_id(self) -> str:
        return str(self.data.get("spec_id", ""))

    @property
    def source_files(self) -> dict[str, str]:
        value = self.data.get("source_files", {})
        return value if isinstance(value, dict) else {}

    @property
    def content_ids(self) -> dict[str, str]:
        value = self.data.get("content_ids", {})
        return value if isinstance(value, dict) else {}

    @property
    def rights(self) -> dict[str, Any]:
        value = self.data.get("rights", {})
        return value if isinstance(value, dict) else {}

    @property
    def review_status(self) -> str:
        return str(self.rights.get("review_status", ""))

    @property
    def commercial_use(self) -> bool:
        return self.rights.get("commercial_use") is True


def load_manifest(package_root: Path) -> AssetManifest:
    manifest_path = package_root / "manifest.json"
    if not manifest_path.exists():
        raise FileNotFoundError(f"missing manifest.json: {manifest_path}")
    return AssetManifest(manifest_path, json.loads(manifest_path.read_text(encoding="utf-8")))


def validate_manifest_shape(manifest: AssetManifest) -> list[str]:
    errors: list[str] = []
    for field in REQUIRED_FIELDS:
        if field not in manifest.data:
            errors.append(f"missing manifest field: {field}")
    for field in REQUIRED_RIGHTS_FIELDS:
        if field not in manifest.rights:
            errors.append(f"missing rights field: rights.{field}")
    if not isinstance(manifest.data.get("content_ids", {}), dict):
        errors.append("content_ids must be an object")
    if not isinstance(manifest.data.get("source_files", {}), dict):
        errors.append("source_files must be an object")
    return errors


def validate_write_rights(manifest: AssetManifest) -> list[str]:
    errors: list[str] = []
    if not manifest.commercial_use:
        errors.append("rights.commercial_use must be true before WriteCsv")
    if manifest.review_status != "approved":
        errors.append("rights.review_status must be approved before WriteCsv")
    return errors

