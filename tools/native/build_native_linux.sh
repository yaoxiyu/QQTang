#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
NATIVE_DIR="$ROOT_DIR/addons/qqt_native"
TARGET="${1:-template_debug}"
ARCH="${2:-x86_64}"
SCONS_EXE="${SCONS_EXE:-scons}"

cd "$NATIVE_DIR"

echo "[qqt_native] build linux target=$TARGET arch=$ARCH"

if ! command -v "$SCONS_EXE" >/dev/null 2>&1; then
  echo "scons is required" >&2
  exit 1
fi

if [[ "$TARGET" != "template_debug" && "$TARGET" != "template_release" ]]; then
  echo "unsupported target: $TARGET" >&2
  exit 1
fi

if [[ "$ARCH" != "x86_64" ]]; then
  echo "unsupported arch: $ARCH" >&2
  exit 1
fi

GODOT_CPP_DIR="$NATIVE_DIR/third_party/godot-cpp"
GODOT_CPP_LIB="$GODOT_CPP_DIR/bin/libgodot-cpp.linux.${TARGET}.${ARCH}.a"

if [[ ! -f "$GODOT_CPP_LIB" ]]; then
  echo "[qqt_native] building missing godot-cpp static library: $GODOT_CPP_LIB"
  "$SCONS_EXE" -C "$GODOT_CPP_DIR" platform=linux target="$TARGET" arch="$ARCH"
fi

"$SCONS_EXE" platform=linux target="$TARGET" arch="$ARCH"

ARTIFACT="$NATIVE_DIR/bin/qqt_native.linux.${TARGET}.${ARCH}.so"
if [[ ! -f "$ARTIFACT" ]]; then
  echo "missing artifact: $ARTIFACT" >&2
  exit 2
fi

echo "[qqt_native] artifact ready: $ARTIFACT"
