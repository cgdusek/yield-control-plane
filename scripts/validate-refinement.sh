#!/usr/bin/env bash
set -euo pipefail

python3 - <<'PY'
from pathlib import Path
import re
import yaml

root = Path(".")
mapping_path = root / "spec/refinement/rust_tla_mapping.yaml"
sweep_path = root / "crates/domain/src/sweep.rs"
refinement_path = root / "crates/domain/src/abstract_refinement.rs"
tla_lifecycle_path = root / "spec/tla/YieldLifecycle.tla"
tla_proofs_path = root / "spec/tla/YieldProofs.tla"

for path in [
    mapping_path,
    sweep_path,
    refinement_path,
    tla_lifecycle_path,
    tla_proofs_path,
]:
    if not path.exists():
        raise SystemExit(f"Missing refinement input: {path}")


def enum_variants(source: str, enum_name: str) -> list[str]:
    match = re.search(rf"pub enum {enum_name}\s*\{{(?P<body>.*?)\n\}}", source, re.S)
    if not match:
        raise SystemExit(f"Could not find Rust enum {enum_name}")
    variants = []
    for raw_line in match.group("body").splitlines():
        line = raw_line.split("//", 1)[0].strip().rstrip(",")
        if re.fullmatch(r"[A-Z][A-Za-z0-9_]*", line):
            variants.append(line)
    if not variants:
        raise SystemExit(f"Rust enum {enum_name} has no parsed variants")
    return variants


def tla_next_actions(source: str) -> set[str]:
    match = re.search(r"\nNext ==(?P<body>.*?)\n\nSpec ==", source, re.S)
    if not match:
        raise SystemExit("Could not find TLA Next operator body")
    return set(re.findall(r"\b([A-Z][A-Za-z0-9_]*)\s*\(", match.group("body")))


mapping = yaml.safe_load(mapping_path.read_text())
sweep_source = sweep_path.read_text()
refinement_source = refinement_path.read_text()
tla_lifecycle = tla_lifecycle_path.read_text()
tla_proofs = tla_proofs_path.read_text()

commands = enum_variants(sweep_source, "SweepCommand")
statuses = set(enum_variants(sweep_source, "SweepStatus"))
tla_action_variants = set(enum_variants(refinement_source, "TlaAction"))
next_actions = tla_next_actions(tla_lifecycle)
proofs = set(re.findall(r"^THEOREM\s+([A-Za-z0-9_]+)\s*==", tla_proofs, re.M))
next_preserves_match = re.search(
    r"THEOREM\s+NextPreservesInv\s*==(?P<body>.*?)(?=\n\nTHEOREM|\n\n====)",
    tla_proofs,
    re.S,
)
if not next_preserves_match:
    raise SystemExit("NextPreservesInv theorem is missing")
next_preserves_body = next_preserves_match.group("body")

mapped_commands = list((mapping.get("commands") or {}).keys())
if mapped_commands != commands:
    raise SystemExit(
        "SweepCommand mapping order mismatch:\n"
        f"  Rust:    {commands}\n"
        f"  Mapping: {mapped_commands}"
    )

creation = mapping.get("creation_boundary") or {}
creation_action = creation.get("tla_action")
if creation_action != "CreateOrder":
    raise SystemExit("creation_boundary.tla_action must be CreateOrder")
if creation_action not in next_actions:
    raise SystemExit("CreateOrder is not present in TLA Next")
if creation_action not in tla_action_variants:
    raise SystemExit("CreateOrder is not present in Rust TlaAction")
if "CreateOrderPreservesInv" not in proofs:
    raise SystemExit("CreateOrderPreservesInv theorem is missing")

preservation_theorems = {f"{action}PreservesInv" for action in next_actions}
missing_preservation_theorems = sorted(preservation_theorems - proofs)
if missing_preservation_theorems:
    raise SystemExit(
        "Every TLA Next action must have an action preservation theorem; missing: "
        f"{missing_preservation_theorems}"
    )

missing_from_next_preserves = sorted(
    theorem for theorem in preservation_theorems if theorem not in next_preserves_body
)
if missing_from_next_preserves:
    raise SystemExit(
        "NextPreservesInv must cite every action preservation theorem; missing: "
        f"{missing_from_next_preserves}"
    )

for command, record in mapping["commands"].items():
    action = record.get("tla_action")
    if not action:
        raise SystemExit(f"{command} is missing tla_action")
    if action == "out_of_scope":
        raise SystemExit(f"{command} cannot be out_of_scope in exhaustive refinement mapping")
    if action not in next_actions:
        raise SystemExit(f"{command} maps to {action}, which is not present in TLA Next")
    if action not in tla_action_variants:
        raise SystemExit(f"{command} maps to {action}, which is not present in Rust TlaAction")

    proof = record.get("proof")
    if proof not in proofs:
        raise SystemExit(f"{command} proof {proof!r} is not declared in YieldProofs.tla")

    from_statuses = record.get("from")
    if not isinstance(from_statuses, list) or not from_statuses:
        raise SystemExit(f"{command} must declare a non-empty from status list")
    unknown_from = sorted(set(from_statuses) - statuses)
    if unknown_from:
        raise SystemExit(f"{command} has unknown from statuses: {unknown_from}")

    to_status = record.get("to")
    if to_status not in statuses:
        raise SystemExit(f"{command} has unknown to status: {to_status}")

unmapped_tla_actions = (
    set(record["tla_action"] for record in mapping["commands"].values())
    | {creation_action}
) - next_actions
if unmapped_tla_actions:
    raise SystemExit(f"Mapped TLA actions missing from Next: {sorted(unmapped_tla_actions)}")

print("Refinement mapping validation passed.")
PY
