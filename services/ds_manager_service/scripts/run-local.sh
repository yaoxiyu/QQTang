#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICE_ROOT="$(dirname "$SCRIPT_DIR")"
ENV_FILE="${1:-$SERVICE_ROOT/.env}"

if [ -f "$ENV_FILE" ]; then
    set -a
    # shellcheck disable=SC1090
    source "$ENV_FILE"
    set +a
fi

cd "$SERVICE_ROOT"
exec go run ./cmd/ds_manager_service
