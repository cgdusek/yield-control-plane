#!/usr/bin/env bash
set -euo pipefail

python3 - <<'PY'
import re
from pathlib import Path

root = Path.cwd()

required = [
    "README.md",
    "AGENTS.md",
    "AGENT_TRACKER.md",
    "docs/index.md",
    "docs/bootstrap.md",
    "docs/architecture.md",
    "docs/local-development.md",
    "docs/testing.md",
    "docs/operations.md",
    "docs/security.md",
    "docs/formal-verification.md",
    "docs/liveness-verification.md",
    "docs/compliance-readiness.md",
    "docs/production-readiness.md",
    "docs/traceability.md",
    "docs/runbooks/index.md",
    "docs/runbooks/localstack-sns-sqs.md",
    "docs/runbooks/postgres-ledger-integrity.md",
    "docs/runbooks/reconciliation-breaks.md",
    "docs/runbooks/kubernetes-kind.md",
    "docs/runbooks/failure-injection.md",
    "docs/runbooks/external-audit-readiness.md",
    "docs/agentic/index.md",
    "docs/agentic/working-agreement.md",
    "docs/agentic/implementation-log.md",
    "docs/agentic/gate-history.md",
    "docs/agentic/docs-generation.md",
    "docs/adr/README.md",
]

missing = [path for path in required if not (root / path).is_file()]
if missing:
    raise SystemExit(f"missing required docs: {missing}")

operational_docs = [
    "docs/architecture.md",
    "docs/local-development.md",
    "docs/testing.md",
    "docs/operations.md",
    "docs/security.md",
    "docs/production-readiness.md",
    "docs/runbooks/localstack-sns-sqs.md",
    "docs/runbooks/postgres-ledger-integrity.md",
    "docs/runbooks/reconciliation-breaks.md",
    "docs/runbooks/kubernetes-kind.md",
    "docs/runbooks/failure-injection.md",
]
for path in operational_docs:
    text = (root / path).read_text()
    if "```bash" not in text and "```sql" not in text:
        raise SystemExit(f"{path} must contain an executable command block")

link_re = re.compile(r"\[[^\]]+\]\(([^)]+)\)")
checked_files = [Path("README.md"), Path("AGENTS.md"), *Path("docs").rglob("*.md")]
for path in checked_files:
    text = (root / path).read_text()
    for raw_target in link_re.findall(text):
        target = raw_target.split("#", 1)[0]
        if not target or target.startswith(("http://", "https://", "mailto:")):
            continue
        resolved = (root / path.parent / target).resolve()
        if not resolved.exists():
            raise SystemExit(f"{path} links to missing target {raw_target}")

banned_re = re.compile(r"\b(TODO|FIXME|TBD)\b|coming soon|lorem ipsum|placeholder", re.IGNORECASE)
for path in [Path("README.md"), *Path("docs").rglob("*.md")]:
    text = (root / path).read_text()
    match = banned_re.search(text)
    if match:
        raise SystemExit(f"{path} contains unfinished marker {match.group(0)!r}")

agents_text = (root / "AGENTS.md").read_text()
if "Every file must either be executable, validated, enforced by tests/scripts/policies" not in agents_text:
    raise SystemExit("AGENTS.md is missing the enforceable-artifact rule")
if "make validate-k8s" not in agents_text:
    raise SystemExit("AGENTS.md must list make validate-k8s")

readme_text = (root / "README.md").read_text()
for command in ("make dev-up", "make smoke", "make smoke-failure-paths", "make validate"):
    if command not in readme_text:
        raise SystemExit(f"README.md must list {command}")

print("documentation links, required docs, runbooks, and enforcement markers validated")
PY
