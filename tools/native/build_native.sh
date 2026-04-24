#!/usr/bin/env bash
set -euo pipefail

PLATFORM="${1:-windows}"
TARGET="${2:-template_debug}"
ARCH="${3:-x86_64}"
SCONS_EXE="${SCONS_EXE:-scons}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
PROJECT_ROOT="${REPO_ROOT}/addons/qqt_native"
SCONSTRUCT_PATH="${PROJECT_ROOT}/SConstruct"
BIN_DIR="${PROJECT_ROOT}/bin"
GODOT_CPP_ROOT="${PROJECT_ROOT}/third_party/godot-cpp"
GODOT_CPP_LIB="${GODOT_CPP_ROOT}/bin/libgodot-cpp.${PLATFORM}.${TARGET}.${ARCH}.lib"

if [[ ! -f "${SCONSTRUCT_PATH}" ]]; then
  echo "SConstruct not found: ${SCONSTRUCT_PATH}" >&2
  exit 1
fi

if [[ "${PLATFORM}" != "windows" ]]; then
  echo "Unsupported platform: ${PLATFORM}. Current repo only ships Windows x86_64 qqt_native artifacts." >&2
  exit 1
fi

if [[ "${TARGET}" != "template_debug" && "${TARGET}" != "template_release" ]]; then
  echo "Unsupported target: ${TARGET}. Supported targets: template_debug, template_release." >&2
  exit 1
fi

if [[ "${ARCH}" != "x86_64" ]]; then
  echo "Unsupported arch: ${ARCH}. Current repo only ships Windows x86_64 qqt_native artifacts." >&2
  exit 1
fi

if [[ ! -f "${GODOT_CPP_LIB}" ]]; then
  echo "[native] building missing godot-cpp static library: ${GODOT_CPP_LIB}"
  "${SCONS_EXE}" -C "${GODOT_CPP_ROOT}" "platform=${PLATFORM}" "target=${TARGET}" "arch=${ARCH}"
fi

echo "[native] building qqt_native platform=${PLATFORM} target=${TARGET} arch=${ARCH}"
"${SCONS_EXE}" -C "${PROJECT_ROOT}" "platform=${PLATFORM}" "target=${TARGET}" "arch=${ARCH}"
echo "[native] build completed"
echo "[native] artifacts directory: ${BIN_DIR}"
if [[ -d "${BIN_DIR}" ]]; then
  find "${BIN_DIR}" -maxdepth 1 -type f -print
fi
