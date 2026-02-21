#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_TEMPLATE="$ROOT_DIR/.env.example"
ENV_FILE="$ROOT_DIR/.env"
CLAWBANDS_CONFIG="$ROOT_DIR/clawbands.config.json"

if [[ ! -f "$ENV_TEMPLATE" ]]; then
  echo "ERROR: Missing template file: $ENV_TEMPLATE" >&2
  exit 1
fi

if [[ ! -f "$ENV_FILE" ]]; then
  cp "$ENV_TEMPLATE" "$ENV_FILE"
  echo "Created $ENV_FILE from $ENV_TEMPLATE."
else
  echo "Using existing $ENV_FILE."
fi

chmod 600 "$ENV_FILE"
echo "Set secure permissions on $ENV_FILE (chmod 600)."

if [[ ! -f "$CLAWBANDS_CONFIG" ]]; then
  echo "ERROR: Missing middleware config: $CLAWBANDS_CONFIG" >&2
  exit 1
fi

"$ROOT_DIR/scripts/preflight-security.sh" \
  --env-file "$ENV_FILE" \
  --clawbands-config "$CLAWBANDS_CONFIG"

cat <<EOF
Secure environment initialization complete.
Next step:
docker compose -f docker-compose.yml -f docker-compose.hardened.yml up -d
EOF
