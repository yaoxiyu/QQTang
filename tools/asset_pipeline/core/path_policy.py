from __future__ import annotations

from pathlib import Path


def ensure_project_relative(path_text: str) -> Path:
    if not path_text or path_text.strip() != path_text:
        raise ValueError("path must be non-empty and trimmed")
    normalized = path_text.replace("\\", "/")
    if normalized.startswith("res://"):
        normalized = normalized.removeprefix("res://")
    if normalized.startswith("/"):
        raise ValueError(f"path must be project-relative: {path_text}")
    path = Path(normalized)
    if path.is_absolute():
        raise ValueError(f"path must be project-relative: {path_text}")
    if any(part == ".." for part in path.parts):
        raise ValueError(f"path must not escape project root: {path_text}")
    return path


def resolve_package_file(package_root: Path, relative_path: str) -> Path:
    rel_path = ensure_project_relative(relative_path)
    full_path = (package_root / rel_path).resolve()
    package_resolved = package_root.resolve()
    if package_resolved not in (full_path, *full_path.parents):
        raise ValueError(f"path escapes package root: {relative_path}")
    return full_path
