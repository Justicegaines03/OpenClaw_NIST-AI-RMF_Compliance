---
title: OpenClaw + PAI Hardened Deployment
---

# OpenClaw + PAI Hardened Deployment

This profile combines OpenClaw automation with PAI's security-first operating model.

## What this hardening does

1. Binds the gateway to loopback host-only ports (`127.0.0.1:18789`, `127.0.0.1:18790`).
2. Enforces container hardening (`no-new-privileges`, `read_only`, `cap_drop=ALL`).
3. Uses an internal Docker network (`internal_only`) for OpenClaw services.
4. Routes all model-provider egress through an allowlisted HTTP CONNECT proxy.
5. Enforces secure secret file permissions (`chmod 600 .env`).
6. Adds `clawbands.config.json` for Human-in-the-Loop policy on B2B sales operations.

## Files in this profile

- `docker-compose.hardened.yml`
- `security/proxy/squid.conf`
- `clawbands.config.json`
- `scripts/init-secure-env.sh`
- `scripts/preflight-env-perms.sh`
- `scripts/preflight-security.sh`
- `scripts/validate-clawbands-config.sh`
- `scripts/hardened-up.sh`

## Required environment variables

Set these in `.env`:

- `GATEWAY_AUTH_TOKEN`
- `ANTHROPIC_API_KEY`
- `AUTHORIZED_USERS` (comma-separated email allowlist)
- `PAI_API_BASE_URL` (default: `http://pai-api:8080`)
- `PAI_API_TOKEN`

## Start hardened profile

```bash
./scripts/hardened-up.sh
```

Equivalent manual command:

```bash
docker compose -f docker-compose.yml -f docker-compose.hardened.yml up -d
```

## Connect to local PAI repo

Your PAI repo is `../Personal_AI_Infrastructure`.

Expose its approval API as `pai-api:8080` on the same Docker network (`internal_only`).

Example PAI compose fragment:

```yaml
services:
  pai-api:
    # image/build for your PAI API service
    expose:
      - "8080"
    networks:
      - internal_only

networks:
  internal_only:
    external: true
    name: internal_only
```

With this pattern, OpenClaw stays isolated on `internal_only` and reaches the internet only through `egress-proxy`.
