# External Audit Readiness Runbook

This runbook prepares an internal evidence packet for a future qualified auditor, counsel, compliance owner, or production owner. It does not create legal advice, regulatory advice, SOC attestation, ISO certification, PCI validation, external audit completion, production authorization, customer-data authorization, or transfer-agent authorization.

## Local Evidence Refresh

Run the static readiness and documentation gates first:

```bash
make validate-standards-readiness
make validate-dfd
make validate-docs
make validate-aws-certification
make validate
```

For a deeper local runtime packet, run the local Compose evidence gates:

```bash
make dev-reset
make dev-up
make smoke
make smoke-failure-paths
make dev-down
```

## Evidence Packet Contents

Collect these repo-local artifacts for review:

- [standards_readiness_map.json](../../spec/certification/standards_readiness_map.json)
- [Standards and certification readiness](../compliance-readiness.md)
- [AWS simulation and internal certification](../aws-certification.md)
- [AWS simulation internal certification report](../certification/aws-simulation-internal-certification-report-2026-06-17.md)
- [Data-flow diagrams and control map](../security/dfd/README.md)
- [Formal verification](../formal-verification.md)
- [Liveness verification](../liveness-verification.md)
- [Production readiness](../production-readiness.md)
- [Traceability](../traceability.md)
- [Security](../security.md)
- `AGENT_TRACKER.md`

## External Evidence Handling

External reports, auditor workpapers, counsel memos, customer contracts, data processing agreements, insurance records, AWS Artifact downloads, and other confidential evidence must stay outside this repo. If a future review needs them, store them in an access-controlled evidence room and reference them by evidence-room identifier in a separate manifest.

## Readiness Review Steps

1. Confirm scope facts: operator, jurisdictions, regulated activities, product boundary, customer data classes, subprocessors, cloud accounts, and production services.
2. Select candidate frameworks from the JSON matrix.
3. For each selected row, verify official source URLs and version dates.
4. Review `repo_evidence` and record whether each artifact is current.
5. Convert `missing_evidence` and `next_actions` into owner-assigned work.
6. Confirm claim boundaries before any external statement leaves engineering review.
7. Rerun `make validate-standards-readiness` after every matrix or dossier edit.

## Stop Conditions

Stop the review and correct the record if any artifact states or implies that the repo has current legal/regulatory clearance, SOC attestation, ISO certification, PCI validation, external audit completion, production authorization, customer-data authorization, or transfer-agent authorization.
