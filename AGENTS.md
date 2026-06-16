# Agent Operating Guide

This repository is gate-driven. Future agents must use [AGENT_TRACKER.md](AGENT_TRACKER.md) as the live control plane and keep it current before starting a gate, after completing a gate, after failures, after design decisions, and before final handoff.

## Non-Negotiable Rules

- Do not make real AWS calls in local/dev mode.
- Do not commit secrets, private keys, real credentials, or production account material.
- Do not imply legal, investment, accounting, tax, regulatory, or production deployment advice.
- Do not claim FIDD balances earn yield. FIDD is modeled only as a payment/stablecoin cash rail.
- Do not mutate order status directly. Use the Rust domain transition function and command handlers.
- Do not create decorative, ornamental, inert, or skeleton artifacts. Every file must either be executable, validated, enforced by tests/scripts/policies, or explicitly tracked as a bounded deferral in `AGENT_TRACKER.md`.
- Do not leave unresolved placeholders such as TODO or FIXME unless the tracker records the exact deferral, reason, owner action, and validation impact.
- Do not mark a gate passed until its success criteria have executable evidence or a documented, justified deferral.

## Required Gates

1. Repository and environment discovery.
2. Source spec ingestion and requirements extraction.
3. Tooling and local bootstrap.
4. Specifications before implementation.
5. Rust workspace and domain core.
6. Persistence, SQL migrations, idempotency, outbox/inbox.
7. Messaging with LocalStack SNS/SQS.
8. Rust API service.
9. Workers and local external simulators.
10. React/TypeScript frontend.
11. Docker Compose full local runtime.
12. Kubernetes local bootstrapping.
13. Observability, security, and operations.
14. CI/CD and final verification.

The source prompt numbers these as Gate 0 through Gate 13. Preserve that numbering in the tracker.

## Validation Commands

Use these commands as the local gate surface:

```bash
make check-tools
make validate-specs
make validate-k8s
make validate-docs
make test
make validate
make dev-up
make smoke
make smoke-failure-paths
make dev-down
```

Kubernetes validation is local-only and depends on kind:

```bash
make k8s-up
make k8s-smoke
make k8s-down
```

If kind, helm, Docker, or another local dependency is unavailable, record the exact blocker in `AGENT_TRACKER.md` and keep the manifests/scripts validated as far as the local environment permits.

## Navigation

- Source request: [spec/source/fidelity_defi_yield_platform_spec.md](spec/source/fidelity_defi_yield_platform_spec.md)
- Tracker: [AGENT_TRACKER.md](AGENT_TRACKER.md)
- Traceability: [docs/traceability.md](docs/traceability.md)
- Specs: [spec/openapi.yaml](spec/openapi.yaml), [spec/asyncapi.yaml](spec/asyncapi.yaml), [spec/domain/sweep_order.machine.yaml](spec/domain/sweep_order.machine.yaml)
- ADRs: [docs/adr/README.md](docs/adr/README.md)
- Agent docs: [docs/agentic/index.md](docs/agentic/index.md)

## Enforcement Expectations

When adding a file, bind it to at least one of:

- a runtime code path;
- a test;
- a validation script;
- a CI step;
- a Docker/Kubernetes runtime path;
- an ADR or runbook whose procedures are used by scripts or operating commands;
- an explicit tracker deferral with reason and follow-up.

If an artifact cannot meet one of those standards, remove it or convert it into an enforceable artifact before proceeding.
