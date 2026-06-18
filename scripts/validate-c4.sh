#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

python3 - <<'PY'
import re
from pathlib import Path

import yaml

root = Path.cwd()
c4_dir = root / "docs/architecture/c4"

required_markdown = [
    "docs/architecture/c4/README.md",
    "docs/architecture/c4/c4-00-system-context.md",
    "docs/architecture/c4/c4-01-local-runtime-containers.md",
    "docs/architecture/c4/c4-02-aws-sandbox-containers.md",
    "docs/architecture/c4/c4-03-api-components.md",
    "docs/architecture/c4/c4-04-worker-components.md",
    "docs/architecture/c4/c4-05-persistence-domain-components.md",
    "docs/architecture/c4/c4-06-ci-evidence-operations.md",
]
required_yaml = [
    "docs/architecture/c4/model-elements.yaml",
    "docs/architecture/c4/relationships.yaml",
    "docs/architecture/c4/deployment-map.yaml",
    "docs/architecture/c4/evidence-map.yaml",
]
tracker = "docs/trackers/c4-evidence-pack.md"
architecture_index = "docs/architecture/README.md"

for path in [*required_markdown, *required_yaml, tracker, architecture_index]:
    if not (root / path).is_file():
        raise SystemExit(f"missing required C4 artifact: {path}")

def load_yaml(path: str):
    try:
        return yaml.safe_load((root / path).read_text())
    except yaml.YAMLError as exc:
        raise SystemExit(f"invalid YAML in {path}: {exc}") from exc

elements_doc = load_yaml("docs/architecture/c4/model-elements.yaml")
relationships_doc = load_yaml("docs/architecture/c4/relationships.yaml")
deployment_doc = load_yaml("docs/architecture/c4/deployment-map.yaml")
evidence_doc = load_yaml("docs/architecture/c4/evidence-map.yaml")
dfd_catalog = load_yaml("docs/security/dfd/data-flow-catalog.yaml")
dfd_controls = load_yaml("docs/security/dfd/control-map.yaml")

dfd_flow_ids = {flow.get("id") for flow in dfd_catalog.get("flows", []) if isinstance(flow, dict)}
dfd_control_ids = {control.get("id") for control in dfd_controls.get("controls", []) if isinstance(control, dict)}

element_items = elements_doc.get("elements")
if not isinstance(element_items, list) or not element_items:
    raise SystemExit("model-elements.yaml must contain a non-empty elements list")

element_id_re = re.compile(r"^(PER|SYS|CON|CMP|MOD)-\d{3}$")
required_element_fields = {
    "id",
    "c4_level",
    "element_type",
    "name",
    "description",
    "responsibilities",
    "technology",
    "deployment_contexts",
    "related_dfd_flows",
    "related_controls",
    "source_files",
}
allowed_element_types = {"person", "software_system", "container", "component", "module"}
elements = {}
for element in element_items:
    if not isinstance(element, dict):
        raise SystemExit("each C4 element must be a YAML mapping")
    missing = sorted(field for field in required_element_fields if field not in element or element[field] in (None, "", [], {}))
    if missing:
        raise SystemExit(f"{element.get('id', '<unknown>')} lacks required element field(s): {missing}")
    element_id = element["id"]
    if not element_id_re.fullmatch(element_id):
        raise SystemExit(f"invalid C4 element id: {element_id}")
    if element_id in elements:
        raise SystemExit(f"duplicate C4 element id: {element_id}")
    if element["element_type"] not in allowed_element_types:
        raise SystemExit(f"{element_id} has unsupported element_type {element['element_type']}")
    unknown_flows = set(element.get("related_dfd_flows", [])) - dfd_flow_ids
    if unknown_flows:
        raise SystemExit(f"{element_id} references unknown DFD flows: {sorted(unknown_flows)}")
    unknown_controls = set(element.get("related_controls", [])) - dfd_control_ids
    if unknown_controls:
        raise SystemExit(f"{element_id} references unknown DFD controls: {sorted(unknown_controls)}")
    for source_file in element["source_files"]:
        if not (root / source_file).exists():
            raise SystemExit(f"{element_id} references missing source file {source_file}")
    elements[element_id] = element

relationship_items = relationships_doc.get("relationships")
if not isinstance(relationship_items, list) or not relationship_items:
    raise SystemExit("relationships.yaml must contain a non-empty relationships list")

relationship_id_re = re.compile(r"^REL-\d{3}$")
required_relationship_fields = {
    "id",
    "source",
    "destination",
    "description",
    "protocol_or_mechanism",
    "interaction_mode",
    "related_dfd_flows",
    "related_diagrams",
    "source_files",
}
allowed_modes = {"synchronous", "asynchronous"}
relationships = {}
for relationship in relationship_items:
    if not isinstance(relationship, dict):
        raise SystemExit("each C4 relationship must be a YAML mapping")
    missing = sorted(field for field in required_relationship_fields if field not in relationship or relationship[field] in (None, "", [], {}))
    if missing:
        raise SystemExit(f"{relationship.get('id', '<unknown>')} lacks required relationship field(s): {missing}")
    relationship_id = relationship["id"]
    if not relationship_id_re.fullmatch(relationship_id):
        raise SystemExit(f"invalid C4 relationship id: {relationship_id}")
    if relationship_id in relationships:
        raise SystemExit(f"duplicate C4 relationship id: {relationship_id}")
    if relationship["source"] not in elements:
        raise SystemExit(f"{relationship_id} references unknown source element {relationship['source']}")
    if relationship["destination"] not in elements:
        raise SystemExit(f"{relationship_id} references unknown destination element {relationship['destination']}")
    if relationship["interaction_mode"] not in allowed_modes:
        raise SystemExit(f"{relationship_id} has unsupported interaction_mode {relationship['interaction_mode']}")
    unknown_flows = set(relationship.get("related_dfd_flows", [])) - dfd_flow_ids
    if unknown_flows:
        raise SystemExit(f"{relationship_id} references unknown DFD flows: {sorted(unknown_flows)}")
    for related_diagram in relationship["related_diagrams"]:
        if not (c4_dir / related_diagram).is_file():
            raise SystemExit(f"{relationship_id} references missing diagram {related_diagram}")
    for source_file in relationship["source_files"]:
        if not (root / source_file).exists():
            raise SystemExit(f"{relationship_id} references missing source file {source_file}")
    relationships[relationship_id] = relationship

boundary_items = deployment_doc.get("boundaries")
if not isinstance(boundary_items, list) or not boundary_items:
    raise SystemExit("deployment-map.yaml must contain boundaries")
boundary_ids = set()
for boundary in boundary_items:
    if not isinstance(boundary, dict):
        raise SystemExit("each C4 boundary must be a YAML mapping")
    for field in ("id", "name", "description", "deployment_contexts", "elements", "residual_assumptions"):
        if field not in boundary or boundary[field] in (None, "", [], {}):
            raise SystemExit(f"{boundary.get('id', '<unknown>')} lacks required boundary field {field}")
    if not re.fullmatch(r"BND-\d{3}", boundary["id"]):
        raise SystemExit(f"invalid boundary id: {boundary['id']}")
    boundary_ids.add(boundary["id"])
    unknown_elements = set(boundary["elements"]) - set(elements)
    if unknown_elements:
        raise SystemExit(f"{boundary['id']} references unknown elements: {sorted(unknown_elements)}")

contexts = deployment_doc.get("deployment_contexts")
if not isinstance(contexts, list) or not contexts:
    raise SystemExit("deployment-map.yaml must contain deployment_contexts")
context_ids = set()
for context in contexts:
    if not isinstance(context, dict):
        raise SystemExit("each deployment context must be a YAML mapping")
    for field in ("id", "name", "description", "boundaries", "elements", "source_files", "validation_commands", "residual_assumptions"):
        if field not in context or context[field] in (None, "", [], {}):
            raise SystemExit(f"{context.get('id', '<unknown>')} lacks required deployment context field {field}")
    context_ids.add(context["id"])
    unknown_boundaries = set(context["boundaries"]) - boundary_ids
    if unknown_boundaries:
        raise SystemExit(f"{context['id']} references unknown boundaries: {sorted(unknown_boundaries)}")
    unknown_elements = set(context["elements"]) - set(elements)
    if unknown_elements:
        raise SystemExit(f"{context['id']} references unknown elements: {sorted(unknown_elements)}")
    for source_file in context["source_files"]:
        if not (root / source_file).exists():
            raise SystemExit(f"{context['id']} references missing source file {source_file}")

for element_id, element in elements.items():
    unknown_contexts = set(element["deployment_contexts"]) - context_ids
    if unknown_contexts:
        raise SystemExit(f"{element_id} references unknown deployment contexts: {sorted(unknown_contexts)}")

evidence_items = evidence_doc.get("evidence_items")
if not isinstance(evidence_items, list) or not evidence_items:
    raise SystemExit("evidence-map.yaml must contain evidence_items")
for evidence in evidence_items:
    if not isinstance(evidence, dict):
        raise SystemExit("each evidence item must be a YAML mapping")
    for field in ("id", "name", "description", "related_elements", "related_relationships", "related_dfd_controls", "validation_commands", "source_files", "residual_gaps"):
        if field not in evidence or evidence[field] in (None, "", [], {}):
            raise SystemExit(f"{evidence.get('id', '<unknown>')} lacks required evidence field {field}")
    if not re.fullmatch(r"EVD-C4-\d{3}", evidence["id"]):
        raise SystemExit(f"invalid evidence id: {evidence['id']}")
    unknown_elements = set(evidence["related_elements"]) - set(elements)
    if unknown_elements:
        raise SystemExit(f"{evidence['id']} references unknown elements: {sorted(unknown_elements)}")
    unknown_relationships = set(evidence["related_relationships"]) - set(relationships)
    if unknown_relationships:
        raise SystemExit(f"{evidence['id']} references unknown relationships: {sorted(unknown_relationships)}")
    unknown_controls = set(evidence["related_dfd_controls"]) - dfd_control_ids
    if unknown_controls:
        raise SystemExit(f"{evidence['id']} references unknown DFD controls: {sorted(unknown_controls)}")
    for source_file in evidence["source_files"]:
        if not (root / source_file).exists():
            raise SystemExit(f"{evidence['id']} references missing source file {source_file}")

diagram_paths = [root / path for path in required_markdown if Path(path).name.startswith("c4-")]
relationship_ref_re = re.compile(r"REL-\d{3}")
diagram_relationship_refs = set()
diagram_element_ref_re = re.compile(r"\b(?:PER|SYS|CON|CMP|MOD)-\d{3}\b")
diagram_boundary_ref_re = re.compile(r"\bBND-\d{3}\b")
diagram_element_refs = set()
diagram_boundary_refs = set()
arrow_re = re.compile(r"(-->|-.->|==>)")
for path in diagram_paths:
    text = path.read_text()
    diagram_relationship_refs.update(relationship_ref_re.findall(text))
    diagram_element_refs.update(diagram_element_ref_re.findall(text))
    diagram_boundary_refs.update(diagram_boundary_ref_re.findall(text))
    in_mermaid = False
    for line_number, line in enumerate(text.splitlines(), start=1):
        stripped = line.strip()
        if stripped == "```mermaid":
            in_mermaid = True
            continue
        if in_mermaid and stripped == "```":
            in_mermaid = False
            continue
        if in_mermaid and arrow_re.search(line) and not relationship_ref_re.search(line):
            raise SystemExit(f"{path.relative_to(root)}:{line_number} has an unlabeled C4 relationship arrow")
        if in_mermaid and re.search(r"\b(classDef|style)\b", line):
            raise SystemExit(f"{path.relative_to(root)}:{line_number} uses color/style syntax; labels must carry meaning")

unknown_diagram_relationships = diagram_relationship_refs - set(relationships)
if unknown_diagram_relationships:
    raise SystemExit(f"diagram references missing from C4 relationships catalog: {sorted(unknown_diagram_relationships)}")
unreferenced_relationships = set(relationships) - diagram_relationship_refs
if unreferenced_relationships:
    raise SystemExit(f"C4 relationships not referenced by any diagram: {sorted(unreferenced_relationships)}")
unknown_diagram_elements = diagram_element_refs - set(elements)
if unknown_diagram_elements:
    raise SystemExit(f"diagram references missing from C4 element catalog: {sorted(unknown_diagram_elements)}")
unknown_diagram_boundaries = diagram_boundary_refs - boundary_ids
if unknown_diagram_boundaries:
    raise SystemExit(f"diagram references missing from C4 boundary catalog: {sorted(unknown_diagram_boundaries)}")

unfinished_re = re.compile(r"\b(TBD|TODO|FIXME)\b", re.IGNORECASE)
claim_re = re.compile(
    r"\b(SOC\s*2\s+certified|SOC\s*2\s+compliant|AWS\s+certified|AWS\s+compliant|"
    r"regulatory\s+approval|production\s+ready|externally\s+audited|certified|compliant|attested)\b",
    re.IGNORECASE,
)
negation_re = re.compile(r"\b(no|not|without|does not|do not|never)\b", re.IGNORECASE)
scan_paths = [root / path for path in [*required_markdown, *required_yaml, tracker, architecture_index]]
for path in scan_paths:
    for line_number, line in enumerate(path.read_text().splitlines(), start=1):
        if unfinished_re.search(line):
            raise SystemExit(f"{path.relative_to(root)}:{line_number} contains unfinished marker")
        if claim_re.search(line) and not negation_re.search(line):
            raise SystemExit(f"{path.relative_to(root)}:{line_number} contains unsupported external-assurance wording: {line.strip()}")

print(
    f"C4 pack validated: {len(elements)} elements, {len(relationships)} relationships, "
    f"{len(boundary_ids)} boundaries, {len(evidence_items)} evidence items"
)
PY
