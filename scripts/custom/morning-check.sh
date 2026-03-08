#!/usr/bin/env bash
set -u

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
LOG_PATH="${OPENCLAW_GATEWAY_LOG:-/tmp/openclaw-gateway.log}"
START_SERVER=0
QUICK_MODE=0

for arg in "$@"; do
  case "$arg" in
    --start-server|-s) START_SERVER=1 ;;
    --quick) QUICK_MODE=1 ;;
    --help|-h)
      echo "Usage: $(basename "$0") [--quick] [--start-server]"
      echo "  --quick         Skip deep security audit"
      echo "  --start-server  Start gateway when not running"
      echo ""
      echo "Env:"
      echo "  OPENCLAW_GATEWAY_LOG=/tmp/openclaw-gateway.log  Startup log path"
      exit 0
      ;;
    *)
      echo "[warn] Unknown argument: $arg"
      ;;
  esac
done

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

gateway_port() {
  node -e '
    const fs = require("node:fs");
    const path = require("node:path");
    try {
      const configPath = path.join(process.env.HOME || "", ".openclaw", "openclaw.json");
      const raw = fs.readFileSync(configPath, "utf8");
      const cfg = JSON.parse(raw);
      const port = Number(cfg?.gateway?.port);
      process.stdout.write(Number.isFinite(port) && port > 0 ? String(port) : "18789");
    } catch {
      process.stdout.write("18789");
    }
  '
}

is_gateway_listening() {
  local port="$1"
  nc -z 127.0.0.1 "$port" >/dev/null 2>&1
}

maybe_start_gateway() {
  local port
  port="$(gateway_port)"
  print_section "Gateway startup"
  if is_gateway_listening "$port"; then
    echo "[ok] Gateway already listening on 127.0.0.1:$port"
    return 0
  fi

  echo "[info] Gateway not listening on 127.0.0.1:$port"
  echo "[info] Starting gateway in background..."
  nohup pnpm openclaw gateway >"$LOG_PATH" 2>&1 &
  local pid=$!
  echo "[info] Spawned PID: $pid"
  echo "[info] Logs: $LOG_PATH"

  local tries=20
  while [ "$tries" -gt 0 ]; do
    if is_gateway_listening "$port"; then
      echo "[ok] Gateway now listening on 127.0.0.1:$port"
      return 0
    fi
    if ! kill -0 "$pid" >/dev/null 2>&1; then
      echo "[warn] Gateway process exited early. Check $LOG_PATH"
      return 1
    fi
    sleep 1
    tries=$((tries - 1))
  done

  echo "[warn] Gateway did not become ready within 20s. Check $LOG_PATH"
  return 1
}

if [ "$START_SERVER" -eq 1 ]; then
  maybe_start_gateway
fi

print_section "Docker daemon"
if docker info >/dev/null 2>&1; then
  echo "[ok] Docker daemon reachable"
else
  echo "[warn] Docker daemon not reachable. Start Docker Desktop first."
fi

run_step "Gateway status" pnpm openclaw status --all
run_step "Channel probe" pnpm openclaw channels status --probe

if [ "$QUICK_MODE" -eq 1 ]; then
  print_section "Security audit"
  echo "[skip] Quick mode selected; skipping deep security audit"
else
  run_step "Security audit (deep json)" pnpm openclaw security audit --deep --json
fi

echo
echo "Morning check complete."
