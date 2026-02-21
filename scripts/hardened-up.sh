#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

"$ROOT_DIR/scripts/init-secure-env.sh"

docker compose \
  -f "$ROOT_DIR/docker-compose.yml" \
  -f "$ROOT_DIR/docker-compose.hardened.yml" \
  up -d egress-proxy openclaw-gateway

echo "Hardened OpenClaw gateway started."
echo "Run the CLI with:"
echo "docker compose -f docker-compose.yml -f docker-compose.hardened.yml run --rm openclaw-cli"
