#!/usr/bin/env sh
set -eu

IMAGE_TAG="${QQT_BATTLE_DS_IMAGE:-qqtang/battle-ds:dev}"
ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"
BATTLE_DS_BINARY="${QQT_BATTLE_DS_BINARY:-build/docker/battle_ds/qqtang_battle_ds.x86_64}"
BATTLE_DS_PACK="${QQT_BATTLE_DS_PACK:-build/docker/battle_ds/qqtang_battle_ds.pck}"
BATTLE_DS_DATA_DIR="${QQT_BATTLE_DS_DATA_DIR:-build/docker/battle_ds/data_QQTang_linuxbsd_x86_64}"
BATTLE_DS_NATIVE_LIB="${QQT_BATTLE_DS_NATIVE_LIB:-build/docker/battle_ds/qqt_native.linux.template_release.x86_64.so}"

cd "$ROOT_DIR"

if [ ! -f "$BATTLE_DS_BINARY" ]; then
  echo "missing Battle DS Linux binary: $BATTLE_DS_BINARY" >&2
  echo "export it first, for example:" >&2
  echo "  powershell -ExecutionPolicy Bypass -File scripts/docker/export_battle_ds_linux.ps1" >&2
  exit 1
fi
if [ ! -f "$BATTLE_DS_PACK" ]; then
  echo "missing Battle DS pack: $BATTLE_DS_PACK" >&2
  echo "export it first, for example:" >&2
  echo "  powershell -ExecutionPolicy Bypass -File scripts/docker/export_battle_ds_linux.ps1" >&2
  exit 1
fi
if [ ! -d "$BATTLE_DS_DATA_DIR" ]; then
  echo "missing Battle DS data directory: $BATTLE_DS_DATA_DIR" >&2
  echo "export it first, for example:" >&2
  echo "  powershell -ExecutionPolicy Bypass -File scripts/docker/export_battle_ds_linux.ps1" >&2
  exit 1
fi
if [ ! -f "$BATTLE_DS_NATIVE_LIB" ]; then
  echo "missing Battle DS native Linux library: $BATTLE_DS_NATIVE_LIB" >&2
  echo "build it first, for example:" >&2
  echo "  powershell -ExecutionPolicy Bypass -File tools/native/build_native_linux_docker.ps1 -Target template_release -Arch x86_64" >&2
  exit 1
fi

docker build -f services/ds_agent/Dockerfile -t "$IMAGE_TAG" .
