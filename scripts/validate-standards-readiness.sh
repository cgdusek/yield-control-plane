#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

python3 - <<'PY'
import json
import re
from pathlib import Path
from urllib.parse import urlparse

root = Path.cwd()
matrix_path = root / "spec/certification/standards_readiness_map.json"

required_files = [
    "docs/compliance-readiness.md",
    "docs/runbooks/external-audit-readiness.md",
    "docs/trackers/standards-readiness-planning.md",
    "docs/trackers/standards-readiness-implementation.md",
    "docs/trackers/standards-readiness-tracking.md",
    "spec/certification/standards_readiness_map.json",
    "scripts/validate-standards-readiness.sh",
]
missing = [path for path in required_files if not (root / path).is_file()]
if missing:
    raise SystemExit(f"missing standards readiness artifact(s): {missing}")

data = json.loads(matrix_path.read_text())
if data.get("schema_version") != "1.0.0":
    raise SystemExit("standards readiness schema_version must be 1.0.0")
if data.get("workstream") != "standards-and-certification-readiness":
    raise SystemExit("unexpected standards readiness workstream")
if data.get("status") != "implemented-gated":
    raise SystemExit("standards readiness status must be implemented-gated")

allowed_applicability = set(data.get("allowed_applicability", []))
expected_applicability = {"applicable", "conditional", "not_applicable", "future_external"}
if allowed_applicability != expected_applicability:
    raise SystemExit(f"allowed_applicability must be {sorted(expected_applicability)}")

allowed_categories = set(data.get("allowed_categories", []))
expected_categories = {
    "external_attestation",
    "external_certification",
    "regulatory_legal",
    "control_framework",
    "cloud_assurance",
    "production_readiness",
}
if allowed_categories != expected_categories:
    raise SystemExit(f"allowed_categories must be {sorted(expected_categories)}")

required_non_claims = {
    "internal_readiness_only",
    "no_legal_or_regulatory_advice",
    "no_soc_or_iso_attestation",
    "no_pci_validation",
    "no_external_audit_completion",
    "no_production_authorization",
    "no_customer_data_authorization",
    "no_transfer_agent_authorization",
}
non_claims = set(data.get("non_claims", []))
if not required_non_claims.issubset(non_claims):
    raise SystemExit(f"missing non-claims: {sorted(required_non_claims - non_claims)}")

required_ids = {
    "soc1-icfr-readiness",
    "soc2-trust-services-readiness",
    "soc3-general-use-readiness",
    "iso27001-isms-readiness",
    "iso27017-cloud-controls-readiness",
    "iso27018-cloud-pii-readiness",
    "iso27701-pims-readiness",
    "iso22301-bcms-readiness",
    "iso20000-1-service-management-readiness",
    "pci-dss-cardholder-data-scope",
    "csa-ccm-caiq-cloud-control-map",
    "csa-star-readiness",
    "ftc-glba-safeguards-rule",
    "sec-regulation-sp",
    "sec-regulation-sci",
    "finra-cybersecurity-readiness",
    "nydfs-part-500-readiness",
    "gdpr-eu-uk-privacy-readiness",
    "eu-dora-operational-resilience",
    "uk-fca-pra-operational-resilience",
    "nist-csf-2-control-map",
    "nist-sp-800-53-r5-control-catalog",
    "cis-controls-v8-1-map",
    "aws-well-architected-fsi-lens",
    "aws-shared-responsibility-and-service-controls",
    "production-readiness-boundary",
}

allowed_source_hosts = {
    "www.aicpa-cima.com",
    "www.iso.org",
    "www.nist.gov",
    "nvlpubs.nist.gov",
    "csrc.nist.gov",
    "www.ftc.gov",
    "www.ecfr.gov",
    "www.sec.gov",
    "www.finra.org",
    "www.dfs.ny.gov",
    "commission.europa.eu",
    "eur-lex.europa.eu",
    "www.eiopa.europa.eu",
    "www.fca.org.uk",
    "www.bankofengland.co.uk",
    "ico.org.uk",
    "www.pcisecuritystandards.org",
    "www.cisecurity.org",
    "cloudsecurityalliance.org",
    "aws.amazon.com",
    "docs.aws.amazon.com",
}

makefile_text = (root / "Makefile").read_text()
make_targets = set(re.findall(r"^([A-Za-z0-9_.-]+):", makefile_text, re.M))
validate_all_text = (root / "scripts/validate-all.sh").read_text()

def fail(message: str) -> None:
    raise SystemExit(message)

def require_list(value, row_id: str, field: str) -> list:
    if not isinstance(value, list) or not value:
        fail(f"{row_id}.{field} must be a non-empty list")
    return value

def check_command(command: str, row_id: str) -> None:
    if command.startswith("make "):
        target = command.split(maxsplit=1)[1]
        if target not in make_targets:
            fail(f"{row_id} references unknown make target: {command}")
    elif command.startswith(("cargo ", "pnpm ", "RUN_DATABASE_TESTS=")):
        return
    else:
        fail(f"{row_id} uses unsupported evidence command: {command}")

def check_evidence_item(item: str, row_id: str) -> None:
    if item.startswith("make ") or item.startswith(("cargo ", "pnpm ", "RUN_DATABASE_TESTS=")):
        check_command(item, row_id)
        return
    if not (root / item).exists():
        fail(f"{row_id} references missing repo evidence: {item}")

rows = data.get("rows")
if not isinstance(rows, list) or not rows:
    fail("rows must be a non-empty list")

seen_ids = set()
for row in rows:
    if not isinstance(row, dict):
        fail("each standards readiness row must be an object")
    row_id = row.get("id")
    if not isinstance(row_id, str) or not row_id:
        fail("each row must have a non-empty id")
    if row_id in seen_ids:
        fail(f"duplicate row id: {row_id}")
    seen_ids.add(row_id)

    for field in ("framework", "category", "applicability", "version_or_status", "claim_boundary"):
        if not isinstance(row.get(field), str) or not row[field].strip():
            fail(f"{row_id}.{field} must be a non-empty string")
    if row["category"] not in allowed_categories:
        fail(f"{row_id}.category has unsupported value {row['category']!r}")
    if row["applicability"] not in allowed_applicability:
        fail(f"{row_id}.applicability has unsupported value {row['applicability']!r}")

    jurisdictions = require_list(row.get("jurisdiction"), row_id, "jurisdiction")
    if not all(isinstance(value, str) and value for value in jurisdictions):
        fail(f"{row_id}.jurisdiction must contain non-empty strings")

    sources = require_list(row.get("official_sources"), row_id, "official_sources")
    for source in sources:
        if not isinstance(source, dict) or not source.get("id") or not source.get("url"):
            fail(f"{row_id}.official_sources entries must have id and url")
        parsed = urlparse(source["url"])
        if parsed.scheme != "https":
            fail(f"{row_id} source must use https: {source['url']}")
        if parsed.netloc not in allowed_source_hosts:
            fail(f"{row_id} source host is not in the approved official-source set: {parsed.netloc}")

    for field in ("repo_evidence", "missing_evidence", "next_actions"):
        values = require_list(row.get(field), row_id, field)
        if not all(isinstance(value, str) and value.strip() for value in values):
            fail(f"{row_id}.{field} must contain non-empty strings")

    for evidence in row["repo_evidence"]:
        check_evidence_item(evidence, row_id)

    if not isinstance(row.get("external_owner_required"), bool):
        fail(f"{row_id}.external_owner_required must be boolean")
    if "Internal readiness only" not in row["claim_boundary"]:
        fail(f"{row_id}.claim_boundary must include 'Internal readiness only'")

    if row["category"] == "regulatory_legal" and row["applicability"] != "conditional":
        fail(f"{row_id} regulatory/legal rows must remain conditional without authoritative operator scope evidence")
    if row["category"] in {"external_attestation", "external_certification"} and row["applicability"] == "applicable":
        fail(f"{row_id} external assurance rows cannot be marked applicable without an external report")
    if row["applicability"] == "future_external" and not row["external_owner_required"]:
        fail(f"{row_id} future_external rows must require an external owner")
    if row["applicability"] == "not_applicable":
        joined_gaps = " ".join(row["missing_evidence"]).lower()
        if "unless" not in joined_gaps and "no " not in joined_gaps:
            fail(f"{row_id} not_applicable rows must state the scope reason and re-entry condition")

missing_required = required_ids - seen_ids
extra_ids = seen_ids - required_ids
if missing_required:
    fail(f"missing required standards rows: {sorted(missing_required)}")
if extra_ids:
    fail(f"unexpected standards rows without validator coverage: {sorted(extra_ids)}")

if "validate-standards-readiness:" not in makefile_text:
    fail("Makefile must expose validate-standards-readiness")
if "./scripts/validate-standards-readiness.sh" not in validate_all_text:
    fail("scripts/validate-all.sh must run validate-standards-readiness")

index_text = (root / "docs/index.md").read_text()
for required_link in (
    "compliance-readiness.md",
    "../spec/certification/standards_readiness_map.json",
):
    if required_link not in index_text:
        fail(f"docs/index.md must link {required_link}")

runbook_index = (root / "docs/runbooks/index.md").read_text()
if "external-audit-readiness.md" not in runbook_index:
    fail("docs/runbooks/index.md must link external-audit-readiness.md")

claim_files = [
    Path("docs/compliance-readiness.md"),
    Path("docs/runbooks/external-audit-readiness.md"),
    Path("docs/trackers/standards-readiness-planning.md"),
    Path("docs/trackers/standards-readiness-implementation.md"),
    Path("docs/trackers/standards-readiness-tracking.md"),
    Path("spec/certification/standards_readiness_map.json"),
]
claim_re = re.compile(r"\b(certified|compliant|approved|production ready)\b", re.I)
negation_re = re.compile(r"\b(no|not|without|never|does not|do not)\b", re.I)
for path in claim_files:
    for line_number, line in enumerate((root / path).read_text().splitlines(), start=1):
        if claim_re.search(line) and not negation_re.search(line):
            fail(f"{path}:{line_number} has unbounded external-assurance wording: {line.strip()}")

unfinished_re = re.compile(r"\b(TODO|FIXME|TBD)\b|coming soon|lorem ipsum|placeholder", re.I)
for path in claim_files:
    text = (root / path).read_text()
    match = unfinished_re.search(text)
    if match:
        fail(f"{path} contains unfinished marker {match.group(0)!r}")

script_text = (root / "scripts/validate-standards-readiness.sh").read_text()
for line_number, line in enumerate(script_text.splitlines(), start=1):
    if re.match(r"^\s*(aws|tofu|opentofu|k6)\b", line):
        fail(f"standards readiness validator must remain non-cloud and non-IaC: line {line_number}")

print(f"standards readiness matrix validated: {len(rows)} rows")
PY
