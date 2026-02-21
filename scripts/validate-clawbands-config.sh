#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_FILE="${1:-$ROOT_DIR/clawbands.config.json}"

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "ERROR: Missing clawbands config: $CONFIG_FILE" >&2
  exit 1
fi

node - "$CONFIG_FILE" <<'NODE'
const fs = require("node:fs");

const path = process.argv[2];
const errors = [];

const mustHaveOps = new Set([
  "lead.create",
  "outreach.email.send",
  "quote.send",
  "contract.send",
  "crm.deal.update",
]);

let parsed;
try {
  parsed = JSON.parse(fs.readFileSync(path, "utf8"));
} catch (error) {
  console.error(`ERROR: Invalid JSON in ${path}: ${error.message}`);
  process.exit(1);
}

if (!Array.isArray(parsed.policies) || parsed.policies.length === 0) {
  errors.push("policies must be a non-empty array");
}

const hitl = Array.isArray(parsed.policies)
  ? parsed.policies.find((item) => item && item.id === "b2b-sales-hitl")
  : undefined;

if (!hitl) {
  errors.push('missing policy id "b2b-sales-hitl"');
} else {
  if (hitl.authorizedUsersEnv !== "AUTHORIZED_USERS") {
    errors.push('b2b-sales-hitl.authorizedUsersEnv must be "AUTHORIZED_USERS"');
  }
  if (hitl?.enforcement?.mode !== "human_in_the_loop_required") {
    errors.push('b2b-sales-hitl.enforcement.mode must be "human_in_the_loop_required"');
  }
  if (hitl?.enforcement?.onMissingApproval !== "deny") {
    errors.push('b2b-sales-hitl.enforcement.onMissingApproval must be "deny"');
  }

  const operations = new Set(hitl?.scope?.operations ?? []);
  for (const op of mustHaveOps) {
    if (!operations.has(op)) {
      errors.push(`b2b-sales-hitl.scope.operations missing "${op}"`);
    }
  }
}

if (errors.length > 0) {
  console.error(`ERROR: ${path} failed validation:`);
  for (const error of errors) {
    console.error(`- ${error}`);
  }
  process.exit(1);
}

console.log(`OK: ${path} passed policy validation.`);
NODE
