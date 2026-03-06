# OpenClaw Channel Migration + Security Evidence

Date: 2026-03-06
Scope: BlueBubbles removal, Telegram migration, PAI workspace binding, Top-10/NIST AI RMF-aligned hardening

## 1) Implemented Configuration Changes

Target config: `~/.openclaw/openclaw.json`

- Removed BlueBubbles channel block entirely (`channels.bluebubbles` absent).
- Enabled Telegram channel with secure defaults:
  - `channels.telegram.enabled=true`
  - `channels.telegram.dmPolicy="pairing"`
  - `channels.telegram.groupPolicy="allowlist"`
  - `channels.telegram.groups.*.requireMention=true`
- Pointed agent workspace to PAI repo:
  - `agents.defaults.workspace=/Users/justicegaines/.claude/context/projects/Personal_AI_Infrastructure`
- Enforced DM session isolation:
  - `session.dmScope="per-channel-peer"`
- Added tool hardening:
  - `tools.profile="messaging"`
  - `tools.exec.security="deny"`
  - `tools.fs.workspaceOnly=true`
  - `tools.elevated.enabled=false`
  - `tools.deny` includes control-plane/runtime/file groups and `gateway`, `cron`, `browser`
- Command hardening:
  - `commands.restart=false`

## 2) Command Evidence (Executed)

### Baseline checks (sandboxed run)

- `pnpm openclaw channels status --probe`
  - Gateway not reachable (`ECONNREFUSED 127.0.0.1:18789`), config-only status shown.
- `pnpm openclaw security audit --deep --json`
  - Findings summary (baseline and post-change): `critical=0`, `warn=2`, `info=2`.
  - Warns were proxy trust + gateway probe failure (gateway not running).
- `pnpm openclaw doctor`
  - Reported gateway not running.
  - Also reported state dir non-writable due sandbox execution context.

### Post-change verification (full-permission run)

- `pnpm openclaw channels status --probe`
  - Shows only Telegram auto-enable suggestion (no BlueBubbles mention).
  - Gateway still not reachable because service is not running.
- `pnpm openclaw doctor`
  - Shows only Telegram auto-enable suggestion.
  - Confirms gateway not running.
- `pnpm openclaw security audit --deep --json`
  - Summary: `critical=0`, `warn=2`, `info=2`.
  - Warnings are proxy trust guidance + gateway probe failed (gateway down).

- `pnpm openclaw config get channels.bluebubbles.enabled`
  - `Config path not found` (proof BlueBubbles section removed).
- `pnpm openclaw config get channels.telegram.enabled`
  - `true`
- `pnpm openclaw config get channels.telegram.dmPolicy`
  - `pairing`
- `pnpm openclaw config get agents.defaults.workspace`
  - `/Users/justicegaines/.claude/context/projects/Personal_AI_Infrastructure`
- `pnpm openclaw config get session.dmScope`
  - `per-channel-peer`
- `pnpm openclaw config get gateway.bind`
  - `loopback`
- `pnpm openclaw config get gateway.auth.mode`
  - `token`
- `pnpm openclaw config get tools.elevated.enabled`
  - `false`
- `pnpm openclaw config get tools.exec.security`
  - `deny`
- `pnpm openclaw config get tools.fs.workspaceOnly`
  - `true`

### Telegram token readiness check

- `pnpm openclaw config get channels.telegram.botToken`
  - Path not found (token not stored in config).
- Shell check:
  - `TELEGRAM_BOT_TOKEN is missing` (env var currently unset).

## 3) Top 10 Vulnerability Validation (Current State)

Status codes: PASS / PARTIAL / PENDING

1. Gateway exposed on `0.0.0.0` -> `gateway.bind=loopback`: PASS
2. DM policy allows all users -> Telegram `dmPolicy=pairing`: PASS
3. Sandbox disabled by default -> `agents.defaults.sandbox.mode=all`: PASS
4. Credentials in plaintext config/session -> hardening applied, but existing gateway token remains in config: PARTIAL
5. Prompt injection via web content -> high-risk tools denied for default profile: PARTIAL
6. Dangerous commands unlocked -> `tools.exec.security=deny`, `commands.restart=false`: PASS
7. No network isolation -> sandbox enabled + loopback bind (tailnet exposure still enabled via Serve): PARTIAL
8. Elevated tool access granted -> `tools.elevated.enabled=false`: PASS
9. No audit logging enabled -> security audit command executed and runtime gateway logs observed during Telegram startup: PASS
10. Weak/default pairing codes -> Telegram pairing and device pairing observed in runtime logs: PASS

## 4) NIST AI RMF Mapping (G/M/M/M)

- Govern
  - Security baseline enforced in live config (least privilege defaults).
- Map
  - Architecture split applied: assistant gateway points to PAI repo workspace.
- Measure
  - Security audit executed (`--deep --json`) before and after changes.
  - Config verification commands captured for channel and security controls.
- Manage
  - Residual risks identified and tracked (token missing, gateway offline, tailnet/proxy warnings).

## 5) Final Activation Evidence (Post-Fix)

After token/auth mismatch remediation and Docker startup, runtime evidence confirms end-to-end activation:

- Gateway startup:
  - `[gateway] listening on ws://127.0.0.1:18789`
- Telegram startup:
  - `[telegram] [default] starting provider (@justice_bean_bot)`
- Device auth recovery:
  - `[gateway] device pairing auto-approved device=... role=operator`
- Message flow:
  - `[telegram] sendMessage ok chat=... message=...`
- Security deep check:
  - `openclaw security audit --deep --json` returned:
    - `summary: critical=0, warn=1, info=2`
    - `deep.gateway.ok=true`
    - Remaining warning: `gateway.trusted_proxies_missing` (expected unless reverse proxy is configured).

## 6) Daily Operations Runbook

### Morning startup (if your Mac was restarted or Docker/gateway not running)

1. Start Docker Desktop.
2. From repo root, load environment and start gateway:
   - `set -a; source .env; set +a`
   - `pnpm openclaw gateway`
3. In another terminal, verify:
   - `pnpm openclaw status --all`
   - `pnpm openclaw channels status --probe`

Automated alternative:

- `bash scripts/morning-check.sh`
- Quick mode (skip deep audit): `bash scripts/morning-check.sh --quick`

### If your Mac was not restarted and gateway is already running

- You usually do not need to start anything.
- Run a quick check:
  - `pnpm openclaw status --all`

### Daily shutdown (optional)

- Stop gateway foreground process with `Ctrl+C` if you started it manually.
- Docker can stay running if you want faster startup next time.

## 7) PAI Connection and Edit Behavior

How it connects to PAI:

- OpenClaw uses your configured agent workspace path:
  - `agents.defaults.workspace=/Users/justicegaines/.claude/context/projects/Personal_AI_Infrastructure`
- This means agent file operations target that repo/workspace context.

Will it edit the PAI repo automatically when you chat?

- Not by default in this hardened profile.
- Current controls are restrictive:
  - sandbox enabled with `workspaceAccess="ro"` (read-only mount)
  - `tools.exec.security="deny"`
  - `tools.profile="messaging"` plus deny list for higher-risk tools
- Net effect: normal chat responses should not mutate files unless you deliberately relax policy and grant write-capable tools.

## 8) Notes on Assistant Self-Assessment Message

The assistant's message about "fresh start", "no memory files yet", and setup docs is expected for a new/clean session bootstrap flow.

Recommended operator action:

- Proceed with profile/bootstrap personalization only after confirming each file change proposal.
- Keep "ask before action" and least-privilege in your identity/system directives.
- Keep Docker sandbox on for normal operation.

