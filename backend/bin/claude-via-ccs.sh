#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
CCS_BIN="${CCS_BIN:-$BACKEND_DIR/node_modules/.bin/ccs}"
CCS_PROFILE_VALUE="${CCS_PROFILE:-}"
export CCS_CLAUDE_PATH="${CCS_CLAUDE_PATH:-$BACKEND_DIR/node_modules/.bin/claude}"

if [[ ! -x "$CCS_BIN" ]]; then
  echo "CCS binary not found: $CCS_BIN" >&2
  exit 1
fi

if [[ -z "$CCS_PROFILE_VALUE" ]]; then
  echo "CCS_PROFILE is required when using claude-via-ccs.sh" >&2
  exit 1
fi

exec "$CCS_BIN" "$CCS_PROFILE_VALUE" "$@"
