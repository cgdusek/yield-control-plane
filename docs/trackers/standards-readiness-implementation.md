# Standards And Certification Readiness Implementation

Status: complete

## Work Breakdown

| Phase | Scope | Primary Files | Status |
| --- | --- | --- | --- |
| S1 | Official-source standards research | `docs/compliance-readiness.md`, `spec/certification/standards_readiness_map.json` | complete |
| S2 | Readiness dossier and runbook | `docs/compliance-readiness.md`, `docs/runbooks/external-audit-readiness.md` | complete |
| S3 | Static validation gate | `scripts/validate-standards-readiness.sh`, `Makefile`, `scripts/validate-all.sh` | complete |
| S4 | Surface coverage integration | `scripts/generate-repo-surface-coverage-map.py`, `spec/refinement/repo_surface_coverage_map.json` | complete |
| S5 | Tracker and validation closure | `AGENT_TRACKER.md`, `docs/trackers/standards-readiness-tracking.md` | complete |

## Edit Plan

Add a JSON matrix as the source of truth and a human-readable dossier that summarizes how to use it. Add a runbook for future external audit preparation without making a current external audit claim.

## Generated Artifact Plan

`spec/refinement/repo_surface_coverage_map.json` remains the only generated artifact touched by this workstream. The standards readiness JSON is hand-maintained because it records researched sources and control decisions.

## Gate Integration Plan

`make validate-standards-readiness` must be non-cloud, deterministic, and included in `make validate`. The validator checks JSON shape, required standards coverage, source URL presence, no-claim boundaries, concrete gaps, and aggregate-gate wiring.

## Risk Register

| Risk | Mitigation |
| --- | --- |
| Internal demo overclaims external assurance | Validator rejects forbidden external-certification and production-ready claim words unless the same line negates them. |
| Legal/regulatory scope is misclassified | Legal/regulatory rows are conditional and require counsel or compliance-owner determination. |
| Matrix becomes stale | Store researched date, source URLs, and next actions; include the validator in full CI. |
| New docs drift outside coverage map | Add a standards-readiness surface to the repo surface generator and regenerate the derived map. |
| External auditor material is treated as public repo content | Runbook keeps auditor-confidential evidence and AWS Artifact downloads outside the repo. |

## Decisions

- Use US + EU/UK scope.
- Use a readiness matrix, not an auditor packet or public whitepaper.
- Treat SOC, ISO, PCI, CSA STAR, and AWS Artifact reports as future or third-party external assurance paths, not current repo claims.
- Treat NIST, CIS, CSA CCM, and AWS Well-Architected as control-mapping aids.
- Keep PCI DSS not applicable to the current repo unless cardholder data enters scope.

## Deferred Items

External auditor engagement, counsel review, formal legal applicability determination, customer-data privacy assessment, production identity and access management, production incident response, and production deployment controls remain outside this implementation and are recorded as next actions in the matrix.
