#!/usr/bin/env bash
set -euo pipefail

python3 - <<'PY'
from pathlib import Path
import json
import sys
import yaml

root = Path(".")
required = [
    "spec/openapi.yaml",
    "spec/asyncapi.yaml",
    "spec/domain/sweep_order.machine.yaml",
    "spec/schemas/events/event-envelope.schema.json",
    "spec/schemas/events/sweep-order-created.v1.schema.json",
    "spec/schemas/events/sweep-cash-locked.v1.schema.json",
    "spec/schemas/events/transfer-agent-confirmed.v1.schema.json",
    "spec/schemas/events/position-booked.v1.schema.json",
    "spec/schemas/events/reconciliation-break-opened.v1.schema.json",
    "spec/tla/no_double_sweep.tla",
    "spec/diagrams/architecture.mmd",
    "spec/diagrams/sweep-order-state-machine.mmd",
    "spec/diagrams/local-runtime.mmd",
]

missing = [p for p in required if not (root / p).exists()]
if missing:
    raise SystemExit(f"Missing spec files: {missing}")

openapi = yaml.safe_load((root / "spec/openapi.yaml").read_text())
asyncapi = yaml.safe_load((root / "spec/asyncapi.yaml").read_text())
machine = yaml.safe_load((root / "spec/domain/sweep_order.machine.yaml").read_text())

for schema_file in (root / "spec/schemas/events").glob("*.json"):
    json.loads(schema_file.read_text())

if openapi.get("openapi") != "3.1.0":
    raise SystemExit("OpenAPI must be 3.1.0")
if "paths" not in openapi:
    raise SystemExit("OpenAPI paths missing")
if "channels" not in asyncapi:
    raise SystemExit("AsyncAPI channels missing")

required_paths = {
    "/health": "get",
    "/ready": "get",
    "/sweep-policies": "post",
    "/sweep-policies/{account_id}": "get",
    "/sweep-orders": "post",
    "/sweep-orders/{order_id}": "get",
    "/sweep-orders/{order_id}/approve": "post",
    "/sweep-orders/{order_id}/cancel": "post",
    "/redemptions": "post",
    "/accounts/{account_id}/positions": "get",
    "/accounts/{account_id}/income": "get",
    "/reconciliation-breaks": "get",
    "/reconciliation-breaks/{break_id}/resolve": "post",
    "/audit-events": "get",
}
for path, method in required_paths.items():
    if method not in openapi["paths"].get(path, {}):
        raise SystemExit(f"OpenAPI missing {method.upper()} {path}")

write_methods = {"post", "put", "patch", "delete"}
for path, methods in openapi["paths"].items():
    for method, operation in methods.items():
        if method in write_methods:
            params = operation.get("parameters", [])
            refs = {p.get("$ref", "") for p in params if isinstance(p, dict)}
            if "#/components/parameters/IdempotencyKey" not in refs:
                raise SystemExit(f"{method.upper()} {path} missing Idempotency-Key")
            if "#/components/parameters/CorrelationId" not in refs:
                raise SystemExit(f"{method.upper()} {path} missing Correlation-Id")

machine_statuses = machine["statuses"]
openapi_statuses = openapi["components"]["schemas"]["SweepStatus"]["enum"]
if machine_statuses != openapi_statuses:
    raise SystemExit("SweepStatus enum mismatch between machine and OpenAPI")

channels = set(asyncapi["channels"].keys())
emitted = set()
for transition in machine["transitions"]:
    for event in transition.get("emits") or []:
        emitted.add(event)
missing_channels = sorted(emitted - channels)
if missing_channels:
    raise SystemExit(f"Machine emits events missing from AsyncAPI: {missing_channels}")

expected_channels = {
    "sweep.order.created.v1",
    "sweep.eligibility.checked.v1",
    "sweep.disclosures.checked.v1",
    "sweep.order.approved.v1",
    "sweep.cash.locked.v1",
    "sweep.subscription.submitted.v1",
    "sweep.transfer_agent.confirmed.v1",
    "sweep.chain_mirror.observed.v1",
    "sweep.position.booked.v1",
    "sweep.reconciled.v1",
    "sweep.active.v1",
    "redemption.requested.v1",
    "redemption.submitted.v1",
    "redemption.confirmed.v1",
    "redemption.cash_credited.v1",
    "reconciliation.break.opened.v1",
    "reconciliation.break.resolved.v1",
    "audit.event.recorded.v1",
}
missing_expected = sorted(expected_channels - channels)
if missing_expected:
    raise SystemExit(f"AsyncAPI missing required channels: {missing_expected}")

print("Spec validation passed.")
PY
