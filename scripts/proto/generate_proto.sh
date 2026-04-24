#!/usr/bin/env bash
set -euo pipefail

fail() {
  echo "ERROR: $1" >&2
  exit "${2:-1}"
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
cd "${REPO_ROOT}"

if ! command -v buf >/dev/null 2>&1; then
  fail "buf not found in PATH. Install buf and retry." 2
fi

generated_roots=(
  "services/room_service/internal/gen"
  "services/game_service/internal/gen"
)

generated_targets=(
  "services/room_service/internal/gen/qqt/room/v1"
  "services/room_service/internal/gen/qqt/internal/game/v1"
  "services/game_service/internal/gen/qqt/room/v1"
  "services/game_service/internal/gen/qqt/internal/game/v1"
  "network/client_net/generated"
)

generated_readme_text=$'# Generated Code\n\nThis directory contains generated code.\n\n- Do not edit files here manually.\n- Source of truth: `proto/`.\n- Update path: run `buf generate` through repository scripts.\n'

for dir in "${generated_roots[@]}"; do
  mkdir -p "${dir}"
  printf '%s' "${generated_readme_text}" > "${dir}/README.md"
done

for dir in "${generated_targets[@]}"; do
  rm -rf "${dir}"
  mkdir -p "${dir}"
done

buf generate || {
  code=$?
  fail "buf generate failed with exit code ${code}." "${code}"
}

echo "Proto generation completed successfully."
