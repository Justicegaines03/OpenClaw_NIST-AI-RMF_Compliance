#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
QUICK_MODE=0
START_SERVER_FLAG=0
DEFAULT_TIMEOUT_SECONDS="${OPENCLAW_DEFAULT_TIMEOUT_SECONDS:-180}"

for arg in "$@"; do
  case "$arg" in
    --quick) QUICK_MODE=1 ;;
    --start-server|-s) START_SERVER_FLAG=1 ;;
    --help|-h)
      echo "Usage: $(basename "$0") [--quick] [--start-server]"
      echo "  --quick         Skip deep security audit in morning check"
      echo "  --start-server  Start gateway during morning check (background)"
      echo ""
      echo "Env:"
      echo "  OPENCLAW_DEFAULT_TIMEOUT_SECONDS=180  Default timeout when unset"
      echo ""
      echo "Default behavior:"
      echo "  1) Run morning check"
      echo "  2) Ensure agents.defaults.timeoutSeconds is set"
      echo "  2) If gateway is not running, start OpenClaw in foreground"
      exit 0
      ;;
    *)
      ;;
  esac
done

MORNING_ARGS=()
if [[ "$QUICK_MODE" -eq 1 ]]; then
  MORNING_ARGS+=(--quick)
fi
if [[ "$START_SERVER_FLAG" -eq 1 ]]; then
  MORNING_ARGS+=(--start-server)
fi

if [[ ${#MORNING_ARGS[@]} -gt 0 ]]; then
  bash "$ROOT_DIR/scripts/custom/morning-check.sh" "${MORNING_ARGS[@]}"
else
  bash "$ROOT_DIR/scripts/custom/morning-check.sh"
fi

if pnpm openclaw config get agents.defaults.timeoutSeconds >/dev/null 2>&1; then
  echo "[ok] agents.defaults.timeoutSeconds already configured."
else
  echo "[info] agents.defaults.timeoutSeconds not set. Applying default: ${DEFAULT_TIMEOUT_SECONDS}s"
  pnpm openclaw config set "agents.defaults.timeoutSeconds" "$DEFAULT_TIMEOUT_SECONDS"
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

PORT="$(gateway_port)"
if is_gateway_listening "$PORT"; then
  echo
  echo "[ok] OpenClaw gateway already running at 127.0.0.1:$PORT."
  echo "You can talk to Rovert now."
  exit 0
fi

echo
echo "Starting OpenClaw gateway in foreground..."
echo "Use Ctrl+C to stop it."
cd "$ROOT_DIR"
exec pnpm openclaw gateway
