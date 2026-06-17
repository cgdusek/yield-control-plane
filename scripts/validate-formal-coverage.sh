#!/usr/bin/env bash
set -euo pipefail

python3 - <<'PY'
from pathlib import Path
import re
import sys
import yaml

root = Path(".")
matrix_path = root / "spec/refinement/invariant_coverage.yaml"
if not matrix_path.exists():
    raise SystemExit("Missing spec/refinement/invariant_coverage.yaml")

matrix = yaml.safe_load(matrix_path.read_text())
required_axes = set(matrix.get("required_axes") or [])
shared = matrix.get("shared") or {}
invariants = matrix.get("invariants") or []

if not required_axes:
    raise SystemExit("required_axes must be non-empty")
if not invariants:
    raise SystemExit("invariants must be non-empty")


def read_required(path_text: str) -> str:
    path = root / path_text
    if not path.exists():
        raise SystemExit(f"Referenced evidence file is missing: {path_text}")
    return path.read_text()


def require_contains(path_text: str, needles: list[str]) -> None:
    text = read_required(path_text)
    for needle in needles or []:
        if not isinstance(needle, str):
            raise SystemExit(f"{path_text} has non-string contains entry: {needle!r}")
        if needle not in text:
            raise SystemExit(f"{path_text} does not contain expected evidence text: {needle}")


tla_module = shared.get("tla_module")
catalog_path = shared.get("invariant_catalog")
proof_module = shared.get("proof_module")
tlc_config = shared.get("tlc_config")
for required in [tla_module, catalog_path, proof_module, tlc_config]:
    if not required:
        raise SystemExit("shared TLA/proof/TLC paths must be populated")

tla_source = read_required(tla_module)
catalog_source = read_required(catalog_path)
proof_source = read_required(proof_module)
cfg_source = read_required(tlc_config)

catalog_match = re.search(r"InvariantCatalog\s*==\s*\{(?P<body>.*?)\}", catalog_source, re.S)
if not catalog_match:
    raise SystemExit("Could not parse InvariantCatalog")
catalog_ids = re.findall(r'"([^"]+)"', catalog_match.group("body"))
matrix_ids = [item.get("id") for item in invariants]
if matrix_ids != catalog_ids:
    raise SystemExit(
        "Invariant coverage matrix must match InvariantCatalog order:\n"
        f"  catalog={catalog_ids}\n"
        f"  matrix={matrix_ids}"
    )

tla_definitions = set(re.findall(r"^([A-Za-z][A-Za-z0-9_]*)\s*==", tla_source, re.M))
proofs = set(re.findall(r"^THEOREM\s+([A-Za-z][A-Za-z0-9_]*)\s*==", proof_source, re.M))
cfg_invariants = set(re.findall(r"^INVARIANT\s+([A-Za-z][A-Za-z0-9_]*)", cfg_source, re.M))
cfg_properties = set(re.findall(r"^PROPERTY\s+([A-Za-z][A-Za-z0-9_]*)", cfg_source, re.M))

makefile = read_required("Makefile")
make_targets = set(re.findall(r"^([A-Za-z0-9_.-]+):", makefile, re.M))
validate_all = read_required("scripts/validate-all.sh")

for validator in shared.get("validators") or []:
    read_required(validator)
    if Path(validator).name != "validate-tla.sh" and validator not in validate_all:
        raise SystemExit(f"{validator} is not invoked by scripts/validate-all.sh")

for command in shared.get("ci_commands") or []:
    if not isinstance(command, str) or not command.startswith("make "):
        raise SystemExit(f"Unsupported CI command format: {command!r}")
    target = command.split(maxsplit=1)[1]
    if target not in make_targets:
        raise SystemExit(f"Make target for CI command is missing: {command}")

for projection in shared.get("rust_projection") or []:
    require_contains(projection["path"], projection.get("contains") or [])

for item in invariants:
    item_id = item.get("id")
    if item.get("status") != "covered":
        raise SystemExit(f"{item_id} must be covered or explicitly removed from the complete matrix")

    axes = set(item.get("axes") or [])
    missing_axes = sorted(required_axes - axes)
    if missing_axes:
        raise SystemExit(f"{item_id} is missing formal coverage axes: {missing_axes}")

    definition = item.get("tla_definition")
    if definition not in tla_definitions:
        raise SystemExit(f"{item_id} TLA definition is missing: {definition}")

    theorem_list = item.get("tlaps_theorems") or []
    if not theorem_list:
        raise SystemExit(f"{item_id} must list TLAPS theorem evidence")
    missing_theorems = sorted(set(theorem_list) - proofs)
    if missing_theorems:
        raise SystemExit(f"{item_id} references missing TLAPS theorem(s): {missing_theorems}")

    tlc = item.get("tlc") or {}
    for invariant in tlc.get("invariants") or []:
        if invariant not in cfg_invariants:
            raise SystemExit(f"{item_id} references missing TLC invariant: {invariant}")
    for prop in tlc.get("properties") or []:
        if prop not in cfg_properties:
            raise SystemExit(f"{item_id} references missing TLC property: {prop}")
    if not (tlc.get("invariants") or tlc.get("properties")):
        raise SystemExit(f"{item_id} must reference a TLC invariant or property")

    rust_tests = item.get("rust_tests") or []
    if not rust_tests:
        raise SystemExit(f"{item_id} must list Rust/property/refinement test evidence")
    for evidence in rust_tests:
        require_contains(evidence["path"], evidence.get("contains") or [])

    runtime = item.get("runtime_enforcement") or []
    if not runtime:
        raise SystemExit(f"{item_id} must list runtime enforcement evidence")
    for evidence in runtime:
        require_contains(evidence["path"], evidence.get("contains") or [])

    docs = read_required("docs/formal-verification.md")
    if item_id not in docs:
        raise SystemExit(f"{item_id} is missing from docs/formal-verification.md")

print("Formal coverage validation passed.")
PY
