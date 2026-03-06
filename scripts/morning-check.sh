#!/usr/bin/env bash
set -u

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

print_section() {
  echo
  echo "== $1 =="
}

run_step() {
  local label="$1"
  shift
  print_section "$label"
  if "$@"; then
    echo "[ok] $label"
    return 0
  fi
  local code=$?
  echo "[warn] $label failed (exit $code)"
  return $code
}

echo "OpenClaw morning check"
echo "Repo: $ROOT_DIR"

cd "$ROOT_DIR" || exit 1

if [ -f ".env" ]; then
  # Export .env values for this script process only.
  set -a
  # shellcheck disable=SC1091
  source ".env"
  set +a
  echo "[ok] Loaded .env"
else
  echo "[warn] .env not found; continuing without it"
fi

print_section "Docker daemon"
if docker info >/dev/null 2>&1; then
  echo "[ok] Docker daemon reachable"
else
  echo "[warn] Docker daemon not reachable. Start Docker Desktop first."
fi

run_step "Gateway status" pnpm openclaw status --all
run_step "Channel probe" pnpm openclaw channels status --probe

if [ "${1:-}" = "--quick" ]; then
  print_section "Security audit"
  echo "[skip] Quick mode selected; skipping deep security audit"
else
  run_step "Security audit (deep json)" pnpm openclaw security audit --deep --json
fi

echo
echo "Morning check complete."
