#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${1:-$ROOT_DIR/.env}"

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

if [[ ! -f "$ENV_FILE" ]]; then
  fail "Missing env file: $ENV_FILE"
fi

get_mode() {
  if stat -f "%Lp" "$1" >/dev/null 2>&1; then
    stat -f "%Lp" "$1"
  else
    stat -c "%a" "$1"
  fi
}

MODE="$(get_mode "$ENV_FILE")"
if [[ "$MODE" != "600" ]]; then
  fail "$ENV_FILE permissions are $MODE; expected 600."
fi

echo "OK: $ENV_FILE has secure permissions (600)."
