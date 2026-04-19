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

for dir in "${generated_roots[@]}"; do
  mkdir -p "${dir}"
  cat > "${dir}/README.md" <<'EOF'
# Generated Code

This directory contains generated code.

- Do not edit files here manually.
- Source of truth: `proto/`.
- Update path: run `buf generate` through repository scripts.
EOF
done

for dir in "${generated_targets[@]}"; do
  rm -rf "${dir}"
  mkdir -p "${dir}"
done

if ! buf generate; then
  code=$?
  fail "buf generate failed with exit code ${code}." "${code}"
fi

echo "Proto generation completed successfully."
