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

if [[ ! -f "${SCONSTRUCT_PATH}" ]]; then
  echo "SConstruct not found: ${SCONSTRUCT_PATH}" >&2
  exit 1
fi

echo "[native] building qqt_native platform=${PLATFORM} target=${TARGET} arch=${ARCH}"
"${SCONS_EXE}" -C "${PROJECT_ROOT}" "platform=${PLATFORM}" "target=${TARGET}" "arch=${ARCH}"
echo "[native] build completed"
echo "[native] artifacts directory: ${BIN_DIR}"
if [[ -d "${BIN_DIR}" ]]; then
  find "${BIN_DIR}" -maxdepth 1 -type f -print
fi
