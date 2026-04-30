from __future__ import annotations

import importlib.util
from pathlib import Path

from .asset_type_plugin import AssetTypePlugin


def _load_plugin_class(plugin_dir: Path) -> type[AssetTypePlugin]:
    plugin_path = plugin_dir / "plugin.py"
    if not plugin_path.exists():
        return AssetTypePlugin
    module_name = f"phase38_asset_plugin_{plugin_dir.name}"
    spec = importlib.util.spec_from_file_location(module_name, plugin_path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"failed to load plugin: {plugin_path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    plugin_class = getattr(module, "Plugin", None)
    if plugin_class is None:
        raise RuntimeError(f"plugin missing Plugin class: {plugin_path}")
    return plugin_class


def discover_plugins(plugins_root: Path) -> dict[str, AssetTypePlugin]:
    plugins: dict[str, AssetTypePlugin] = {}
    if not plugins_root.exists():
        return plugins
    for plugin_dir in sorted(path for path in plugins_root.iterdir() if path.is_dir()):
        plugin_class = _load_plugin_class(plugin_dir)
        plugin = plugin_class(plugin_dir)
        plugin.load_schema()
        asset_type = getattr(plugin, "asset_type", "") or plugin_dir.name
        if asset_type in plugins:
            raise ValueError(f"duplicate asset plugin: {asset_type}")
        plugins[asset_type] = plugin
    return plugins

