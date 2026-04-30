from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

from .asset_manifest import AssetManifest, load_manifest


@dataclass(frozen=True)
class AssetPackage:
    root: Path
    manifest: AssetManifest

    @classmethod
    def from_root(cls, root: Path) -> "AssetPackage":
        return cls(root=root, manifest=load_manifest(root))

    @property
    def report_dir(self) -> Path:
        return self.root / "reports"

