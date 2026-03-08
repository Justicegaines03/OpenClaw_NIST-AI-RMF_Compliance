# Daniel Miessler Top 10 Security Baseline Evidence

Date: 2026-03-08
Scope: OpenClaw + PAI hardening baseline and control mapping using Daniel Miessler's "Top 10 vulnerabilities" framing (not OWASP Top 10)

## Source and framing

- Framework source: Daniel Miessler "Top 10 vulnerabilities" concept as provided in operator artifact.
- Local visual artifact: `assets/unnamed-8951b05b-6abe-4cd0-b09f-0eff88d9d81d.png`
- Policy note: this evidence record is the canonical markdown source-of-truth. The image is a supporting visual.

## Top 10 vulnerabilities and control mappings

Status legend: REQUIRED / RECOMMENDED / OPTIONAL

1) Gateway exposed on `0.0.0.0:18789`
- Risk: remote unauthorized access to control/data plane if auth is weak or absent.
- Control: enforce loopback bind and strong gateway auth token.
- OpenClaw config paths:
  - `gateway.bind="loopback"`
  - `gateway.auth.mode="token"`
  - `gateway.auth.token` from environment secret, not hardcoded.
- Verification:
  - `openclaw security audit --deep --json`
  - `openclaw config get gateway.bind`
  - `openclaw config get gateway.auth.mode`
- Priority: REQUIRED

2) DM policy allows all users
- Risk: untrusted user ingress drives model/tool behavior.
- Control: pair/allowlist DM policy with explicit authorized users.
- OpenClaw config paths:
  - `channels.<provider>.dmPolicy="pairing"` or `"allowlist"`
  - channel allowlists explicitly set.
- Verification:
  - `openclaw security audit --json`
  - `openclaw config get channels.<provider>.dmPolicy`
- Priority: REQUIRED

3) Sandbox disabled by default
- Risk: model-triggered tool execution can touch host directly.
- Control: force sandbox for relevant agents/sessions and avoid host-network mode.
- OpenClaw config paths:
  - `agents.defaults.sandbox.mode="all"` (or strict per-agent equivalent)
  - `agents.*.sandbox.docker.network` not `host`.
- Verification:
  - `openclaw security audit --deep --json`
  - `openclaw sandbox explain --session <session_key>`
- Priority: REQUIRED

4) Credentials in plaintext config/session
- Risk: secret disclosure through config files, logs, or transcripts.
- Control: use environment or secret providers, strict file permissions.
- OpenClaw config and ops:
  - keep sensitive values out of committed config
  - `chmod 600` for secret-bearing files, least-privilege state dir perms.
- Verification:
  - `openclaw security audit --fix --json` (safe permission tightening)
  - manual review of config for hardcoded secrets.
- Priority: REQUIRED

5) Prompt injection via web content
- Risk: adversarial content manipulates model into unsafe actions.
- Control: treat external content as untrusted, isolate and constrain tool access.
- OpenClaw controls:
  - strict tool profile and deny high-risk tools in untrusted paths
  - sandboxing for tool-enabled agents
  - strong model tier for tool-enabled agents.
- Verification:
  - policy review of `tools.profile`, `tools.allow`, `tools.deny`
  - `openclaw security audit --json`
- Priority: REQUIRED

6) Dangerous commands unlocked
- Risk: direct command execution leads to host compromise or data loss.
- Control: deny exec/process unless explicitly needed; keep approvals strict.
- OpenClaw config paths:
  - `tools.exec.security="deny"` (or strict allowlist + ask)
  - deny `group:runtime` where possible.
- Verification:
  - `openclaw config get tools.exec.security`
  - `openclaw security audit --json`
- Priority: REQUIRED

7) No network isolation
- Risk: unrestricted egress/lateral movement and data exfiltration.
- Control: isolate runtime networks and prefer internal-only paths.
- OpenClaw controls:
  - sandbox docker network isolation
  - loopback-first gateway exposure model.
- Verification:
  - `openclaw security audit --deep --json`
  - inspect effective sandbox/docker network settings.
- Priority: REQUIRED

8) Elevated tool access granted
- Risk: broad privileged tool execution beyond intended trust boundary.
- Control: disable elevated by default and minimize tool set.
- OpenClaw config paths:
  - `tools.elevated.enabled=false`
  - narrow tool allowlist, deny control-plane/runtime tools unless required.
- Verification:
  - `openclaw config get tools.elevated.enabled`
  - `openclaw security audit --json`
- Priority: REQUIRED

9) No audit logging enabled
- Risk: weak incident detection and forensic traceability.
- Control: enable session/log retention and regular audit runs.
- OpenClaw controls:
  - session transcripts retained under state dir
  - periodic `openclaw security audit` execution.
- Verification:
  - confirm session logs exist for active agent
  - `openclaw security audit --deep --json`.
- Priority: REQUIRED

10) Weak/default pairing codes
- Risk: unauthorized enrollment through guessable or weak join controls.
- Control: cryptographically strong random pairing codes and rate limiting.
- OpenClaw behavior:
  - pairing workflow with bounded pending requests and expiry.
- Verification:
  - `openclaw pairing list <channel>`
  - operational test of pairing/approval flow.
- Priority: REQUIRED

## NIST AI RMF alignment statement

This evidence supports NIST AI RMF-aligned operations by documenting controls across:
- Govern: policy and trust-boundary definitions.
- Map: ingress, tooling, sandbox, and credential attack surfaces.
- Measure: repeatable command-based validation of control state.
- Manage: compensating controls, residual risk acceptance, and rollback paths.

## Full `~/.claude` access decision gate (high-trust)

Granting an agent read+write access to all of `~/.claude` is a high-trust configuration and is not "secure by default." It is permitted only when all controls below are in place and accepted by the operator:

Required gate before enablement:
- sandbox enabled for the target agent (`mode="all"` or strict equivalent)
- explicit minimal tool policy (deny by default, then allow only needed tools)
- gateway loopback bind + strong auth token
- elevated tooling disabled (or tightly restricted per sender/agent)
- logging and transcript retention enabled
- documented rollback procedure tested.

Recommended rollback:
- remove broad bind mount for `~/.claude`
- remove external bind-source override
- restart/reload gateway
- re-run `openclaw sandbox explain` and `openclaw security audit --deep --json`.

## Review cadence

- Re-validate this baseline on any policy/sandbox/tooling changes.
- Re-validate at least weekly for active deployments.
- Record deltas in a dated evidence file under `security/evidence/`.
