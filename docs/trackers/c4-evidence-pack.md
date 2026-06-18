# C4 Evidence Pack Tracker

Status: complete
Branch: `codex/docs-c4-evidence-pack`
Base: `docs/dfd-evidence-pack`
Last Updated: 2026-06-18T19:48:47Z

## Objective

Add a docs-as-code C4 architecture evidence pack using Markdown, Mermaid, and YAML metadata. The pack complements the DFD evidence pack by mapping actors, systems, containers, components, relationships, deployment contexts, controls, and source evidence for the existing Yield Control Plane implementation.

## Scope

The pack covers C4 Levels 1 through 3 for the local Docker Compose runtime, Rust services and crates, React console, Postgres, LocalStack SNS/SQS, non-production AWS sandbox simulation, CI validation, and evidence artifact paths.

## Non-Claims

This work does not create SOC attestation, AWS assurance, regulatory approval, legal advice, investment advice, tax advice, accounting advice, transfer-agent authorization, customer-data authorization, production deployment authorization, or production readiness. FIDD remains modeled only as a payment and stablecoin cash rail, not as a yield-bearing balance.

## Files Inspected

- `AGENTS.md`
- `AGENT_TRACKER.md`
- `README.md`
- `docs/index.md`
- `docs/architecture/README.md`
- `docs/security.md`
- `docs/aws-certification.md`
- `docs/security/dfd/README.md`
- `docs/security/dfd/data-flow-catalog.yaml`
- `docs/security/dfd/control-map.yaml`
- `docker-compose.yml`
- `.github/workflows/ci.yml`
- `Makefile`
- `scripts/validate-all.sh`
- `scripts/validate-docs.sh`
- `scripts/validate-dfd.sh`
- `scripts/generate-repo-surface-coverage-map.py`
- `spec/openapi.yaml`
- `spec/asyncapi.yaml`
- `spec/domain/sweep_order.machine.yaml`
- `spec/diagrams/architecture.mmd`
- `infra/aws-simulation/main.tf`
- `infra/aws-simulation/variables.tf`
- `services/api/src/lib.rs`
- `services/api/src/routes/mod.rs`
- `services/api/src/middleware/mod.rs`
- `services/worker/src/main.rs`
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
- `crates/messaging/src/localstack.rs`
- `crates/messaging/src/sns.rs`
- `crates/messaging/src/sqs.rs`
- `crates/config/src/lib.rs`
- `web/react-console/src/App.tsx`
- `web/react-console/src/api/client.ts`

## C4 Artifacts Created

- `docs/architecture/c4/README.md`
- `docs/architecture/c4/c4-00-system-context.md`
- `docs/architecture/c4/c4-01-local-runtime-containers.md`
- `docs/architecture/c4/c4-02-aws-sandbox-containers.md`
- `docs/architecture/c4/c4-03-api-components.md`
- `docs/architecture/c4/c4-04-worker-components.md`
- `docs/architecture/c4/c4-05-persistence-domain-components.md`
- `docs/architecture/c4/c4-06-ci-evidence-operations.md`
- `docs/architecture/c4/model-elements.yaml`
- `docs/architecture/c4/relationships.yaml`
- `docs/architecture/c4/deployment-map.yaml`
- `docs/architecture/c4/evidence-map.yaml`
- `scripts/validate-c4.sh`

## Validation Gates

| Command | Result | Notes |
| --- | --- | --- |
| `bash -n scripts/validate-c4.sh` | passed | Shell syntax check passed. |
| `make validate-c4` | passed | 49 elements, 82 relationships, 11 boundaries, and 7 evidence items validated. |
| `make validate-docs` | passed | Documentation links, required docs, runbooks, and enforcement markers validated. |
| `make validate-dfd` | passed | Existing DFD pack remained green after C4 cross-references and architecture move. |
| `make generate-repo-surface-coverage-map` | passed | Regenerated `spec/refinement/repo_surface_coverage_map.json` with C4 surface coverage. |
| `make validate-repo-surface-coverage-map` | passed | Repository surface coverage JSON map is current. |
| `make validate` | failed | First run failed at repo-surface drift because tracker edits happened after map generation; regenerate the map and rerun. |
| `make validate` | passed | Full validation passed after regenerating the repo surface map. |
| `git diff --check` | passed | No whitespace errors. |
| `test ! -d .tlacache && test ! -d states` | passed | Generated TLA/TLAPS/TLC state is not present. |

## Known Residual Gaps

- C4 Level 4 code diagrams are outside the first C4 evidence pack; source-file evidence references provide code traceability.
- SVG, PDF, and draw.io exports are outside this change and remain optional external packet polish.
- External auditor sampling, management assertion, private evidence rooms, and production architecture approval remain outside this repo.
- Production identity, network segmentation, retention, backup, restore, and external transfer-agent contracts remain production-owner work.

## Completion Checklist

| Item | Status | Evidence |
| --- | --- | --- |
| Source inspection | complete | Files listed above |
| Tracker opened | complete | `AGENT_TRACKER.md`, this tracker |
| Architecture path migration | complete | `docs/architecture/README.md`; links and docs validator updated |
| C4 Markdown diagrams | complete | `docs/architecture/c4/*.md` |
| YAML source catalogs | complete | `model-elements.yaml`, `relationships.yaml`, `deployment-map.yaml`, `evidence-map.yaml` |
| C4 validator | complete | `scripts/validate-c4.sh`; `make validate-c4` passed |
| Makefile and full-gate wiring | complete | `Makefile`, `scripts/validate-all.sh` |
| Docs navigation | complete | `README.md`, `docs/index.md`, security, AWS, architecture, external audit runbook |
| Repo surface coverage | complete | `scripts/generate-repo-surface-coverage-map.py`, `spec/refinement/repo_surface_coverage_map.json` |
| Final validation | complete | `make validate`, `git diff --check`, and generated-state cleanup check passed |
