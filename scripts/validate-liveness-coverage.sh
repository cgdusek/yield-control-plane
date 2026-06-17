#!/usr/bin/env bash
set -euo pipefail

python3 - <<'PY'
from pathlib import Path
import re
import yaml

root = Path(".")
matrix_path = root / "spec/refinement/liveness_coverage.yaml"
if not matrix_path.exists():
    raise SystemExit("Missing spec/refinement/liveness_coverage.yaml")

matrix = yaml.safe_load(matrix_path.read_text())
required_axes = set(matrix.get("required_axes") or [])
shared = matrix.get("shared") or {}
properties = matrix.get("properties") or []
allowed_statuses = set(shared.get("allowed_statuses") or [])

if not required_axes:
    raise SystemExit("required_axes must be non-empty")
if not properties:
    raise SystemExit("properties must be non-empty")
if not allowed_statuses:
    raise SystemExit("shared.allowed_statuses must be populated")


def read_required(path_text: str) -> str:
    path = root / path_text
    if not path.exists():
        raise SystemExit(f"Referenced liveness evidence file is missing: {path_text}")
    return path.read_text()


def require_contains(path_text: str, needles: list[str]) -> None:
    text = read_required(path_text)
    for needle in needles or []:
        if not isinstance(needle, str):
            raise SystemExit(f"{path_text} has non-string contains entry: {needle!r}")
        if needle not in text:
            raise SystemExit(f"{path_text} does not contain expected evidence text: {needle}")


tla_module = shared.get("tla_module")
if not tla_module:
    raise SystemExit("shared.tla_module must be populated")
tla_source = read_required(tla_module)
tla_definitions = set(re.findall(r"^([A-Za-z][A-Za-z0-9_]*)\s*==", tla_source, re.M))

proof_module = shared.get("proof_module")
if not proof_module:
    raise SystemExit("shared.proof_module must be populated")
proof_source = read_required(proof_module)
proofs = set(re.findall(r"^THEOREM\s+([A-Za-z][A-Za-z0-9_]*)\s*==", proof_source, re.M))

makefile = read_required("Makefile")
make_targets = set(re.findall(r"^([A-Za-z0-9_.-]+):", makefile, re.M))
validate_all = read_required("scripts/validate-all.sh")

for validator in shared.get("validators") or []:
    read_required(validator)
    if validator not in validate_all and Path(validator).name != "validate-tla.sh":
        raise SystemExit(f"{validator} is not invoked by scripts/validate-all.sh")

for command in shared.get("ci_commands") or []:
    if not isinstance(command, str) or not command.startswith("make "):
        raise SystemExit(f"Unsupported CI command format: {command!r}")
    target = command.split(maxsplit=1)[1]
    if target not in make_targets:
        raise SystemExit(f"Make target for CI command is missing: {command}")

docs = read_required("docs/liveness-verification.md")

for item in properties:
    item_id = item.get("id")
    if item.get("status") not in allowed_statuses:
        raise SystemExit(f"{item_id} has unsupported status {item.get('status')!r}")

    axes = set(item.get("axes") or [])
    missing_axes = sorted(required_axes - axes)
    if missing_axes:
        raise SystemExit(f"{item_id} is missing liveness coverage axes: {missing_axes}")

    prop = item.get("tla_property")
    if prop not in tla_definitions:
        raise SystemExit(f"{item_id} TLA temporal property is missing: {prop}")

    fairness = item.get("fairness")
    if fairness not in tla_definitions:
        raise SystemExit(f"{item_id} fairness spec is missing from TLA module: {fairness}")

    tlaps = item.get("tlaps") or {}
    if not isinstance(tlaps, dict):
        raise SystemExit(f"{item_id} must include tlaps proof feasibility metadata")

    temporal_feasible = tlaps.get("temporal_property_feasible")
    if not isinstance(temporal_feasible, bool):
        raise SystemExit(f"{item_id} tlaps.temporal_property_feasible must be true or false")

    property_theorems = tlaps.get("property_theorems") or []
    supporting_theorems = tlaps.get("supporting_safety_theorems") or []
    if temporal_feasible:
        if not property_theorems:
            raise SystemExit(f"{item_id} must list TLAPS property_theorems when temporal_property_feasible is true")
        missing_property_theorems = sorted(set(property_theorems) - proofs)
        if missing_property_theorems:
            raise SystemExit(f"{item_id} references missing TLAPS property theorem(s): {missing_property_theorems}")
    else:
        reason = tlaps.get("infeasible_reason") or ""
        reason_lower = reason.lower()
        for keyword in ["tlaps", "temporal", "fair"]:
            if keyword not in reason_lower:
                raise SystemExit(
                    f"{item_id} TLAPS infeasibility reason must explicitly mention {keyword!r}: {reason!r}"
                )

    if not supporting_theorems:
        raise SystemExit(f"{item_id} must list supporting TLAPS safety theorem evidence")
    missing_supporting = sorted(set(supporting_theorems) - proofs)
    if missing_supporting:
        raise SystemExit(f"{item_id} references missing supporting TLAPS theorem(s): {missing_supporting}")

    assumptions = item.get("assumptions") or []
    if not assumptions:
        raise SystemExit(f"{item_id} must list explicit liveness assumptions")

    cfg_path = item.get("tlc_config")
    cfg_source = read_required(cfg_path)
    if f"PROPERTY {prop}" not in cfg_source:
        raise SystemExit(f"{item_id} TLC config {cfg_path} does not check {prop}")
    if f"SPECIFICATION {fairness}" not in cfg_source:
        raise SystemExit(f"{item_id} TLC config {cfg_path} does not use {fairness}")

    for group in ["rust_tests", "runtime_enforcement", "observability"]:
        evidence = item.get(group) or []
        if not evidence:
            raise SystemExit(f"{item_id} must list {group} evidence")
        for record in evidence:
            require_contains(record["path"], record.get("contains") or [])

    if item_id not in docs or prop not in docs or fairness not in docs:
        raise SystemExit(f"{item_id} is missing from docs/liveness-verification.md")
    for theorem in property_theorems + supporting_theorems:
        if theorem not in docs:
            raise SystemExit(f"{item_id} TLAPS theorem {theorem} is missing from docs/liveness-verification.md")

print("Liveness coverage validation passed.")
PY
