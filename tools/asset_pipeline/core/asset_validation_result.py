from __future__ import annotations

from dataclasses import dataclass, field


@dataclass
class StageResult:
    stage: str
    status: str = "pass"
    errors: list[str] = field(default_factory=list)
    warnings: list[str] = field(default_factory=list)
    outputs: list[str] = field(default_factory=list)

    def fail(self, message: str) -> None:
        self.status = "fail"
        self.errors.append(message)

    def warn(self, message: str) -> None:
        if self.status == "pass":
            self.status = "warning"
        self.warnings.append(message)

    def to_dict(self) -> dict[str, object]:
        return {
            "stage": self.stage,
            "status": self.status,
            "errors": self.errors,
            "warnings": self.warnings,
            "outputs": self.outputs,
        }


@dataclass
class PipelineResult:
    package_path: str
    asset_type: str
    asset_key: str
    spec_id: str
    stages: list[StageResult] = field(default_factory=list)
    csv_patch_summary: list[dict[str, object]] = field(default_factory=list)
    generated_files: list[str] = field(default_factory=list)
    rights_status: str = ""
    content_hash: str = ""

    @property
    def ok(self) -> bool:
        return all(stage.status != "fail" for stage in self.stages)

    def to_dict(self) -> dict[str, object]:
        return {
            "package_path": self.package_path,
            "asset_type": self.asset_type,
            "asset_key": self.asset_key,
            "spec_id": self.spec_id,
            "status": "pass" if self.ok else "fail",
            "stage_results": [stage.to_dict() for stage in self.stages],
            "csv_patch_summary": self.csv_patch_summary,
            "generated_files": self.generated_files,
            "rights_status": self.rights_status,
            "content_hash": self.content_hash,
        }

