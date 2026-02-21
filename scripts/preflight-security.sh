#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$ROOT_DIR/.env"
CLAWBANDS_CONFIG="$ROOT_DIR/clawbands.config.json"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env-file)
      ENV_FILE="$2"
      shift 2
      ;;
    --clawbands-config)
      CLAWBANDS_CONFIG="$2"
      shift 2
      ;;
    *)
      echo "ERROR: Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

read_env_value() {
  local key="$1"
  local file="$2"
  local value
  value="$(grep -E "^${key}=" "$file" | tail -n 1 | cut -d '=' -f 2- || true)"
  printf '%s' "$value"
}

"$ROOT_DIR/scripts/preflight-env-perms.sh" "$ENV_FILE"
"$ROOT_DIR/scripts/validate-clawbands-config.sh" "$CLAWBANDS_CONFIG"

GATEWAY_AUTH_TOKEN="$(read_env_value "GATEWAY_AUTH_TOKEN" "$ENV_FILE")"
if [[ -z "$GATEWAY_AUTH_TOKEN" || "$GATEWAY_AUTH_TOKEN" == "change-me-to-a-long-random-token" ]]; then
  fail "Set GATEWAY_AUTH_TOKEN in $ENV_FILE to a long random value."
fi
if [[ "${#GATEWAY_AUTH_TOKEN}" -lt 32 ]]; then
  fail "GATEWAY_AUTH_TOKEN must be at least 32 characters."
fi

ANTHROPIC_API_KEY="$(read_env_value "ANTHROPIC_API_KEY" "$ENV_FILE")"
if [[ -z "$ANTHROPIC_API_KEY" || "$ANTHROPIC_API_KEY" == "sk-ant-..." ]]; then
  fail "Set ANTHROPIC_API_KEY in $ENV_FILE."
fi

AUTHORIZED_USERS="$(read_env_value "AUTHORIZED_USERS" "$ENV_FILE")"
if [[ -z "$AUTHORIZED_USERS" ]]; then
  fail "Set AUTHORIZED_USERS in $ENV_FILE (comma-separated emails)."
fi

IFS=',' read -r -a USER_ARRAY <<<"$AUTHORIZED_USERS"
if [[ ${#USER_ARRAY[@]} -eq 0 ]]; then
  fail "AUTHORIZED_USERS must include at least one email address."
fi
for raw_user in "${USER_ARRAY[@]}"; do
  user="${raw_user#"${raw_user%%[![:space:]]*}"}"
  user="${user%"${user##*[![:space:]]}"}"
  if [[ -z "$user" || "$user" != *@*.* ]]; then
    fail "AUTHORIZED_USERS contains invalid email: '$raw_user'."
  fi
done

echo "OK: security preflight checks passed."
