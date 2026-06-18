# DFD Evidence Pack Tracker

Status: complete
Branch: `docs/dfd-evidence-pack`
Base: `main`
Last Updated: 2026-06-18T17:00:58Z

## Objective

Add an audit-ready Data-Flow Diagram evidence pack using Markdown, Mermaid, and YAML metadata as docs-as-code source material for SOC 2, AWS, and financial-control readiness review.

## Scope

The pack describes existing Yield Control Plane data flows, trust boundaries, data classes, controls, and source-file evidence for the local runtime and non-production AWS sandbox simulation. Mermaid diagrams are the visual view. YAML catalogs are the structured audit evidence.

## Non-Claims

This work does not create SOC attestation, AWS assurance, regulatory approval, legal advice, investment advice, accounting advice, tax advice, transfer-agent authorization, customer-data authorization, production deployment authorization, or production readiness. FIDD remains modeled only as a payment and stablecoin cash rail, not as a yield-bearing balance.

## Files Inspected

- `README.md`
- `AGENTS.md`
- `AGENT_TRACKER.md`
- `docs/index.md`
- `docs/architecture/README.md`
- `docs/security.md`
- `docs/aws-certification.md`
- `docs/runbooks/aws-simulation.md`
- `docs/runbooks/external-audit-readiness.md`
- `docs/certification/aws-simulation-internal-certification-report-2026-06-17.md`
- `docs/compliance-readiness.md`
- `spec/openapi.yaml`
- `spec/asyncapi.yaml`
- `spec/domain/sweep_order.machine.yaml`
- `spec/certification/aws_certification_coverage_map.json`
- `infra/aws-simulation/main.tf`
- `infra/aws-simulation/variables.tf`
- `scripts/aws-cert-run.sh`
- `scripts/aws-cert-collect.sh`
- `scripts/aws-cert-wait-queues-drained.sh`
- `scripts/smoke-create-sweep.sh`
- `scripts/smoke-failure-paths.sh`
- `scripts/validate-docs.sh`
- `scripts/validate-all.sh`
- `scripts/generate-repo-surface-coverage-map.py`
- `services/api/src/routes/mod.rs`
- `services/worker/src/workers/mod.rs`
- `services/certifier/src/main.rs`
- `services/mock-transfer-agent/src/main.rs`
- `crates/domain/src/sweep.rs`
- `crates/domain/src/events.rs`
- `crates/domain/src/ledger.rs`
- `crates/persistence/src/repositories.rs`
- `crates/persistence/src/outbox.rs`
- `crates/persistence/src/inbox.rs`
- `crates/persistence/migrations/20260616150400_initial.sql`
- `crates/messaging/src/sns.rs`
- `crates/messaging/src/sqs.rs`
- `crates/config/src/lib.rs`

## DFD Artifacts Created

- `docs/security/dfd/README.md`
- `docs/security/dfd/dfd-00-system-boundary.md`
- `docs/security/dfd/dfd-01-logical-runtime.md`
- `docs/security/dfd/dfd-02-aws-certification-sandbox.md`
- `docs/security/dfd/dfd-03-sweep-order-flow.md`
- `docs/security/dfd/dfd-04-redemption-flow.md`
- `docs/security/dfd/dfd-05-reconciliation-exception-flow.md`
- `docs/security/dfd/data-flow-catalog.yaml`
- `docs/security/dfd/data-classification.yaml`
- `docs/security/dfd/trust-boundaries.yaml`
- `docs/security/dfd/control-map.yaml`
- `scripts/validate-dfd.sh`

## Validation Gates

| Command | Result | Notes |
| --- | --- | --- |
| `bash -n scripts/validate-dfd.sh` | passed | Shell syntax check passed. |
| `make validate-dfd` | passed | 25 flows, 14 controls, and 9 trust boundaries validated. |
| `make validate-docs` | passed | Documentation links, required docs, runbooks, and marker checks passed. |
| `make validate-aws-certification` | passed | Existing AWS sandbox static validation remained green. |
| `make generate-repo-surface-coverage-map` | passed | Regenerated `spec/refinement/repo_surface_coverage_map.json` with DFD surface coverage. |
| `make validate-repo-surface-coverage-map` | passed | Repository surface coverage JSON map is current. |
| `make validate` | passed | Full validation passed, including formal, source-proof, spec, Kubernetes, AWS static, standards, DFD, docs, Rust, and frontend gates. |
| `git diff --check` | passed | No whitespace errors. |
| `test ! -d .tlacache`; `test ! -d states` | passed | Generated TLA/TLAPS/TLC state is not present. |

## Known Residual Gaps

- External auditor sampling, management assertion, control-period evidence, private AWS Artifact material, and customer-data privacy procedures remain outside this repo.
- The DFD pack is source-backed documentation evidence; it does not export SVG/PDF diagrams in this change.
- Production identity, production TLS, production retention schedules, production backup and restore operations, and external transfer-agent contracts remain production-owner work.
- The current public runtime exposes redemption request creation; full redemption settlement and cash-credit progression is modeled by the domain transition path and tests rather than a dedicated public runtime workflow.

## Completion Checklist

| Item | Status | Evidence |
| --- | --- | --- |
| Source inspection | complete | Files listed above |
| DFD Markdown diagrams | complete | `docs/security/dfd/*.md` |
| YAML source catalogs | complete | `data-flow-catalog.yaml`, `data-classification.yaml`, `trust-boundaries.yaml`, `control-map.yaml` |
| DFD validator | complete | `scripts/validate-dfd.sh`; `make validate-dfd` passed |
| Makefile and full-gate wiring | complete | `Makefile`, `scripts/validate-all.sh` |
| Docs navigation | complete | `README.md`, `docs/index.md`, security, architecture, AWS docs, external audit runbook |
| Repo surface coverage | complete | `scripts/generate-repo-surface-coverage-map.py`, `spec/refinement/repo_surface_coverage_map.json` |
| Final validation | complete | Commands listed in validation gates passed |
