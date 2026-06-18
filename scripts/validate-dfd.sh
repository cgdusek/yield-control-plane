#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

python3 - <<'PY'
import re
from pathlib import Path

import yaml

root = Path.cwd()
dfd_dir = root / "docs/security/dfd"

required_markdown = [
    "docs/security/dfd/README.md",
    "docs/security/dfd/dfd-00-system-boundary.md",
    "docs/security/dfd/dfd-01-logical-runtime.md",
    "docs/security/dfd/dfd-02-aws-certification-sandbox.md",
    "docs/security/dfd/dfd-03-sweep-order-flow.md",
    "docs/security/dfd/dfd-04-redemption-flow.md",
    "docs/security/dfd/dfd-05-reconciliation-exception-flow.md",
]
required_yaml = [
    "docs/security/dfd/data-flow-catalog.yaml",
    "docs/security/dfd/data-classification.yaml",
    "docs/security/dfd/trust-boundaries.yaml",
    "docs/security/dfd/control-map.yaml",
]
tracker = "docs/trackers/dfd-evidence-pack.md"

for path in [*required_markdown, *required_yaml, tracker]:
    if not (root / path).is_file():
        raise SystemExit(f"missing required DFD artifact: {path}")

def load_yaml(path: str):
    try:
        return yaml.safe_load((root / path).read_text())
    except yaml.YAMLError as exc:
        raise SystemExit(f"invalid YAML in {path}: {exc}") from exc

catalog = load_yaml("docs/security/dfd/data-flow-catalog.yaml")
classifications = load_yaml("docs/security/dfd/data-classification.yaml")
boundaries = load_yaml("docs/security/dfd/trust-boundaries.yaml")
controls = load_yaml("docs/security/dfd/control-map.yaml")

classification_ids = set((classifications.get("classes") or {}).keys())
boundary_ids = {item.get("id") for item in boundaries.get("boundaries", []) if isinstance(item, dict)}
control_items = controls.get("controls", [])
control_ids = {item.get("id") for item in control_items if isinstance(item, dict)}

required_control_fields = {
    "id",
    "name",
    "description",
    "control_type",
    "owner_role",
    "frequency",
    "evidence",
    "related_flows",
    "related_files",
    "soc2_category_relevance",
    "aws_relevance",
    "residual_gaps",
}
allowed_control_types = {"preventive", "detective", "corrective"}

flows = catalog.get("flows")
if not isinstance(flows, list) or not flows:
    raise SystemExit("data-flow-catalog.yaml must contain a non-empty flows list")

flow_ids = []
flow_by_id = {}
required_flow_fields = {
    "id",
    "name",
    "description",
    "source",
    "destination",
    "trust_boundaries_crossed",
    "protocol_or_mechanism",
    "data_elements",
    "data_classification",
    "purpose",
    "trigger",
    "persistence",
    "retention",
    "authentication",
    "authorization",
    "encryption_in_transit",
    "encryption_at_rest",
    "integrity_controls",
    "replay_or_deduplication_controls",
    "logging_and_audit_evidence",
    "monitoring_or_alerting",
    "failure_mode",
    "recovery_or_compensation",
    "related_controls",
    "related_diagrams",
    "source_files",
}

for flow in flows:
    if not isinstance(flow, dict):
        raise SystemExit("each flow must be a YAML mapping")
    missing = sorted(field for field in required_flow_fields if field not in flow or flow[field] in (None, "", [], {}))
    if missing:
        raise SystemExit(f"{flow.get('id', '<unknown>')} lacks required field(s): {missing}")
    flow_id = flow["id"]
    if not re.fullmatch(r"DF-\d{3}", flow_id):
        raise SystemExit(f"invalid data-flow id: {flow_id}")
    if flow_id in flow_by_id:
        raise SystemExit(f"duplicate data-flow id: {flow_id}")
    flow_ids.append(flow_id)
    flow_by_id[flow_id] = flow

    if flow["data_classification"] not in classification_ids:
        raise SystemExit(f"{flow_id} references unknown classification {flow['data_classification']}")
    unknown_boundaries = set(flow["trust_boundaries_crossed"]) - boundary_ids
    if unknown_boundaries:
        raise SystemExit(f"{flow_id} references unknown trust boundaries: {sorted(unknown_boundaries)}")
    unknown_controls = set(flow["related_controls"]) - control_ids
    if unknown_controls:
        raise SystemExit(f"{flow_id} references unknown controls: {sorted(unknown_controls)}")

    for related_diagram in flow["related_diagrams"]:
        if not (dfd_dir / related_diagram).is_file():
            raise SystemExit(f"{flow_id} references missing diagram {related_diagram}")
    for source_file in flow["source_files"]:
        if not (root / source_file).exists():
            raise SystemExit(f"{flow_id} references missing source file {source_file}")

    restricted = flow["data_classification"].startswith("restricted") or flow["data_classification"] == "confidential"
    if restricted:
        for field in ("encryption_in_transit", "encryption_at_rest", "authentication", "authorization", "logging_and_audit_evidence"):
            if flow.get(field) in (None, "", [], {}):
                raise SystemExit(f"{flow_id} restricted/confidential flow lacks {field}")

for control in control_items:
    if not isinstance(control, dict):
        raise SystemExit("each control must be a YAML mapping")
    missing = sorted(field for field in required_control_fields if field not in control or control[field] in (None, "", [], {}))
    if missing:
        raise SystemExit(f"{control.get('id', '<unknown>')} lacks required field(s): {missing}")
    if control["control_type"] not in allowed_control_types:
        raise SystemExit(f"{control['id']} has unsupported control_type {control['control_type']}")
    unknown_flows = set(control["related_flows"]) - set(flow_ids)
    if unknown_flows:
        raise SystemExit(f"{control['id']} references unknown flows: {sorted(unknown_flows)}")
    for related_file in control["related_files"]:
        if not (root / related_file).exists():
            raise SystemExit(f"{control['id']} references missing related file {related_file}")

for boundary in boundaries.get("boundaries", []):
    for crossing_flow in boundary.get("crossing_flows", []):
        if crossing_flow not in flow_by_id:
            raise SystemExit(f"{boundary.get('id')} references unknown crossing flow {crossing_flow}")
    unknown_controls = set(boundary.get("required_controls", [])) - control_ids
    if unknown_controls:
        raise SystemExit(f"{boundary.get('id')} references unknown controls: {sorted(unknown_controls)}")

diagram_paths = [root / path for path in required_markdown if Path(path).name.startswith("dfd-")]
df_re = re.compile(r"DF-\d{3}")
diagram_refs = set()
for path in diagram_paths:
    text = path.read_text()
    diagram_refs.update(df_re.findall(text))
    in_mermaid = False
    for line_number, line in enumerate(text.splitlines(), start=1):
        stripped = line.strip()
        if stripped == "```mermaid":
            in_mermaid = True
            continue
        if in_mermaid and stripped == "```":
            in_mermaid = False
            continue
        if in_mermaid and "-->" in line and not df_re.search(line):
            raise SystemExit(f"{path.relative_to(root)}:{line_number} has an unlabeled DFD arrow")
        if in_mermaid and re.search(r"\b(classDef|style)\b", line):
            raise SystemExit(f"{path.relative_to(root)}:{line_number} uses color/style syntax; labels must carry meaning")

unknown_diagram_refs = diagram_refs - set(flow_ids)
if unknown_diagram_refs:
    raise SystemExit(f"diagram references missing from data-flow catalog: {sorted(unknown_diagram_refs)}")
unreferenced_flows = set(flow_ids) - diagram_refs
if unreferenced_flows:
    raise SystemExit(f"catalog flows not referenced by any diagram: {sorted(unreferenced_flows)}")

unfinished_re = re.compile(r"\b(TBD|TODO|FIXME)\b", re.IGNORECASE)
claim_re = re.compile(
    r"\b(SOC\s*2\s+certified|SOC\s*2\s+compliant|AWS\s+certified|AWS\s+compliant|"
    r"regulatory\s+approval|production\s+ready|externally\s+audited|certified|compliant|attested)\b",
    re.IGNORECASE,
)
negation_re = re.compile(r"\b(no|not|without|does not|do not|never)\b", re.IGNORECASE)
scan_paths = [root / path for path in [*required_markdown, *required_yaml, tracker]]
for path in scan_paths:
    for line_number, line in enumerate(path.read_text().splitlines(), start=1):
        if unfinished_re.search(line):
            raise SystemExit(f"{path.relative_to(root)}:{line_number} contains unfinished marker")
        if claim_re.search(line) and not negation_re.search(line):
            raise SystemExit(f"{path.relative_to(root)}:{line_number} contains unsupported external-assurance wording: {line.strip()}")

print(f"DFD pack validated: {len(flow_ids)} flows, {len(control_ids)} controls, {len(boundary_ids)} trust boundaries")
PY
