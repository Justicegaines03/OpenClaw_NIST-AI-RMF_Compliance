---
title: PAI Integration Contract
---

# PAI Integration Contract

This document defines the OpenClaw to PAI approval API contract for HITL enforcement.

## Endpoint

- Method: `POST`
- Path: `/v1/approvals/verify`
- Base URL: `PAI_API_BASE_URL` (default `http://pai-api:8080`)
- Auth: `Authorization: Bearer ${PAI_API_TOKEN}`
- Content type: `application/json`

## Request body

```json
{
  "operation_id": "op_123",
  "operation_type": "quote.send",
  "actor_email": "alice@example.com",
  "payload_hash": "sha256:...",
  "requested_at": "2026-02-21T22:00:00Z",
  "approval_token": "signed-token-from-approver"
}
```

## Response body

```json
{
  "approved": true,
  "approval_id": "apr_456",
  "approver": "manager@example.com",
  "expires_at": "2026-02-21T22:15:00Z",
  "reason": "Approved by policy"
}
```

## Fail-closed behavior

OpenClaw must deny the operation if:

1. The endpoint is unreachable or times out.
2. The API returns a non-2xx status.
3. `approved` is not `true`.
4. `approval_id` is missing.
5. `expires_at` is missing or already expired.
